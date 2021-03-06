/* valagdbusmodule.vala
 *
 * Copyright (C) 2010  Jürg Billeter
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Jürg Billeter <j@bitron.ch>
 */

public class Vala.GDBusModule : GVariantModule {
	public static string? get_dbus_name (TypeSymbol symbol) {
		var dbus = symbol.get_attribute ("DBus");
		if (dbus == null) {
			return null;
		}

		return dbus.get_string ("name");
	}

	public static string get_dbus_name_for_member (Symbol symbol) {
		var dbus = symbol.get_attribute ("DBus");
		if (dbus != null && dbus.has_argument ("name")) {
			return dbus.get_string ("name");
		}

		return Symbol.lower_case_to_camel_case (symbol.name);
	}

	public static bool is_dbus_no_reply (Method m) {
		var dbus_attribute = m.get_attribute ("DBus");
		if (dbus_attribute != null
		    && dbus_attribute.has_argument ("no_reply")
		    && dbus_attribute.get_bool ("no_reply")) {
			return true;
		}

		return false;
	}

	public override void visit_error_domain (ErrorDomain edomain) {
		var edomain_dbus_name = get_dbus_name (edomain);
		if (edomain_dbus_name == null) {
			base.visit_error_domain (edomain);
			return;
		}

		generate_error_domain_declaration (edomain, cfile);

		if (!edomain.is_internal_symbol ()) {
			generate_error_domain_declaration (edomain, header_file);
		}
		if (!edomain.is_private_symbol ()) {
			generate_error_domain_declaration (edomain, internal_header_file);
		}

		var error_entries = new CCodeInitializerList ();
		foreach (ErrorCode ecode in edomain.get_codes ()) {
			var ecode_dbus_name = get_dbus_name (ecode);
			if (ecode_dbus_name == null) {
				ecode_dbus_name = Symbol.lower_case_to_camel_case (ecode.name.down ());
			}

			var error_entry = new CCodeInitializerList ();
			error_entry.append (new CCodeIdentifier (ecode.get_cname ()));
			error_entry.append (new CCodeConstant ("\"%s.%s\"".printf (edomain_dbus_name, ecode_dbus_name)));
			error_entries.append (error_entry);
		}

		var cdecl = new CCodeDeclaration ("const GDBusErrorEntry");
		cdecl.add_declarator (new CCodeVariableDeclarator (edomain.get_lower_case_cname () + "_entries[]", error_entries));
		cdecl.modifiers = CCodeModifiers.STATIC;
		cfile.add_constant_declaration (cdecl);

		string quark_fun_name = edomain.get_lower_case_cprefix () + "quark";

		var cquark_fun = new CCodeFunction (quark_fun_name, gquark_type.data_type.get_cname ());
		var cquark_block = new CCodeBlock ();

		string quark_name = "%squark_volatile".printf (edomain.get_lower_case_cprefix ());

		cdecl = new CCodeDeclaration ("gsize");
		cdecl.add_declarator (new CCodeVariableDeclarator (quark_name, new CCodeConstant ("0")));
		cdecl.modifiers = CCodeModifiers.STATIC | CCodeModifiers.VOLATILE;
		cquark_block.add_statement (cdecl);

		var register_call = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_error_register_error_domain"));
		register_call.add_argument (new CCodeConstant ("\"" + edomain.get_lower_case_cname () + "-quark\""));
		register_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (quark_name)));
		register_call.add_argument (new CCodeIdentifier (edomain.get_lower_case_cname () + "_entries"));
		var nentries = new CCodeFunctionCall (new CCodeIdentifier ("G_N_ELEMENTS"));
		nentries.add_argument (new CCodeIdentifier (edomain.get_lower_case_cname () + "_entries"));
		register_call.add_argument (nentries);
		cquark_block.add_statement (new CCodeExpressionStatement (register_call));

		cquark_block.add_statement (new CCodeReturnStatement (new CCodeCastExpression (new CCodeIdentifier (quark_name), "GQuark")));

		cquark_fun.block = cquark_block;
		cfile.add_function (cquark_fun);
	}

	bool is_file_descriptor (DataType type) {
		if (type is ObjectType) {
			if (type.data_type.get_full_name () == "GLib.UnixInputStream" ||
			    type.data_type.get_full_name () == "GLib.UnixOutputStream" ||
			    type.data_type.get_full_name () == "GLib.Socket") {
				return true;
			}
		}

		return false;
	}

	public bool dbus_method_uses_file_descriptor (Method method) {
		foreach (Parameter param in method.get_parameters ()) {
			if (is_file_descriptor (param.variable_type)) {
				return true;
			}
		}

		if (is_file_descriptor (method.return_type)) {
			return true;
		}

		return false;
	}

	CCodeExpression? get_file_descriptor (DataType type, CCodeExpression expr) {
		if (type is ObjectType) {
			if (type.data_type.get_full_name () == "GLib.UnixInputStream") {
				var result = new CCodeFunctionCall (new CCodeIdentifier ("g_unix_input_stream_get_fd"));
				result.add_argument (expr);
				return result;
			} else if (type.data_type.get_full_name () == "GLib.UnixOutputStream") {
				var result = new CCodeFunctionCall (new CCodeIdentifier ("g_unix_output_stream_get_fd"));
				result.add_argument (expr);
				return result;
			} else if (type.data_type.get_full_name () == "GLib.Socket") {
				var result = new CCodeFunctionCall (new CCodeIdentifier ("g_socket_get_fd"));
				result.add_argument (expr);
				return result;
			}
		}

		return null;
	}

	public void send_dbus_value (DataType type, CCodeExpression builder_expr, CCodeExpression expr, Symbol? sym) {
		var fd = get_file_descriptor (type, expr);
		if (fd != null) {
			// add file descriptor to the file descriptor list
			var fd_append = new CCodeFunctionCall (new CCodeIdentifier ("g_unix_fd_list_append"));
			fd_append.add_argument (new CCodeIdentifier ("_fd_list"));
			fd_append.add_argument (fd);
			fd_append.add_argument (new CCodeConstant ("NULL"));

			// add index to file descriptor to gvariant
			var builder_add = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_add"));
			builder_add.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, builder_expr));
			builder_add.add_argument (new CCodeConstant ("\"h\""));
			builder_add.add_argument (fd_append);
			ccode.add_expression (builder_add);
		} else {
			write_expression (type, builder_expr, expr, sym);
		}
	}

	CCodeExpression? create_from_file_descriptor (DataType type, CCodeExpression expr) {
		if (type is ObjectType) {
			if (type.data_type.get_full_name () == "GLib.UnixInputStream") {
				var result = new CCodeFunctionCall (new CCodeIdentifier ("g_unix_input_stream_new"));
				result.add_argument (expr);
				result.add_argument (new CCodeConstant ("TRUE"));
				return new CCodeCastExpression (result, "GUnixInputStream *");
			} else if (type.data_type.get_full_name () == "GLib.UnixOutputStream") {
				var result = new CCodeFunctionCall (new CCodeIdentifier ("g_unix_output_stream_new"));
				result.add_argument (expr);
				result.add_argument (new CCodeConstant ("TRUE"));
				return new CCodeCastExpression (result, "GUnixOutputStream *");
			} else if (type.data_type.get_full_name () == "GLib.Socket") {
				var result = new CCodeFunctionCall (new CCodeIdentifier ("g_socket_new_from_fd"));
				result.add_argument (expr);
				result.add_argument (new CCodeConstant ("NULL"));
				return result;
			}
		}

		return null;
	}

	public void receive_dbus_value (DataType type, CCodeExpression message_expr, CCodeExpression iter_expr, CCodeExpression target_expr, Symbol? sym, CCodeExpression? error_expr = null, out bool may_fail = null) {
		var fd_list = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_get_unix_fd_list"));
		fd_list.add_argument (message_expr);

		var fd = new CCodeFunctionCall (new CCodeIdentifier ("g_unix_fd_list_get"));
		fd.add_argument (fd_list);
		fd.add_argument (new CCodeIdentifier ("_fd_index"));
		fd.add_argument (new CCodeConstant ("NULL"));

		var stream = create_from_file_descriptor (type, fd);
		if (stream != null) {
			var get_fd = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_iter_next"));
			get_fd.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, iter_expr));
			get_fd.add_argument (new CCodeConstant ("\"h\""));
			get_fd.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_fd_index")));
			ccode.add_expression (get_fd);

			ccode.add_assignment (target_expr, stream);
		} else {
			read_expression (type, iter_expr, target_expr, sym, error_expr, out may_fail);
		}
	}
}
