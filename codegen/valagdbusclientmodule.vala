/* valagdbusclientmodule.vala
 *
 * Copyright (C) 2010-2011  Jürg Billeter
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
 * 	Philip Van Hoof <pvanhoof@gnome.org>
 */

public class Vala.GDBusClientModule : GDBusModule {
	enum CallType {
		SYNC,
		ASYNC,
		FINISH,
		NO_REPLY
	}

	public CCodeConstant get_dbus_timeout (Symbol symbol) {
		int timeout = -1;

		var dbus = symbol.get_attribute ("DBus");
		if (dbus != null && dbus.has_argument ("timeout")) {
			timeout = dbus.get_integer ("timeout");
		} else if (symbol.parent_symbol != null) {
			return get_dbus_timeout (symbol.parent_symbol);
		}

		return new CCodeConstant (timeout.to_string ());
	}

	public override void generate_dynamic_method_wrapper (DynamicMethod method) {
		var dynamic_method = (DynamicMethod) method;

		var func = new CCodeFunction (method.get_cname ());
		func.modifiers = CCodeModifiers.STATIC;

		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		generate_cparameters (method, cfile, cparam_map, func);

		push_function (func);

		if (dynamic_method.dynamic_type.data_type == dbus_proxy_type) {
			generate_marshalling (method, CallType.SYNC, null, method.name);
		} else {
			Report.error (method.source_reference, "dynamic methods are not supported for `%s'".printf (dynamic_method.dynamic_type.to_string ()));
		}

		pop_function ();

		cfile.add_function_declaration (func);
		cfile.add_function (func);
	}

	void generate_proxy_interface_init (Interface main_iface, Interface iface) {
		// also generate proxy for prerequisites
		foreach (var prereq in iface.get_prerequisites ()) {
			if (prereq.data_type is Interface) {
				generate_proxy_interface_init (main_iface, (Interface) prereq.data_type);
			}
		}

		string lower_cname = main_iface.get_lower_case_cprefix () + "proxy";

		var proxy_iface_init = new CCodeFunction (lower_cname + "_" + iface.get_lower_case_cprefix () + "interface_init", "void");
		proxy_iface_init.add_parameter (new CCodeParameter ("iface", iface.get_cname () + "Iface*"));

		var iface_block = new CCodeBlock ();

		foreach (Method m in iface.get_methods ()) {
			if (!m.is_abstract) {
				continue;
			}

			var vfunc_entry = new CCodeMemberAccess.pointer (new CCodeIdentifier ("iface"), m.vfunc_name);
			if (!m.coroutine) {
				iface_block.add_statement (new CCodeExpressionStatement (new CCodeAssignment (vfunc_entry, new CCodeIdentifier (generate_dbus_proxy_method (main_iface, iface, m)))));
			} else {
				iface_block.add_statement (new CCodeExpressionStatement (new CCodeAssignment (vfunc_entry, new CCodeIdentifier (generate_async_dbus_proxy_method (main_iface, iface, m)))));
				vfunc_entry = new CCodeMemberAccess.pointer (new CCodeIdentifier ("iface"), m.get_finish_vfunc_name ());
				iface_block.add_statement (new CCodeExpressionStatement (new CCodeAssignment (vfunc_entry, new CCodeIdentifier (generate_finish_dbus_proxy_method (main_iface, iface, m)))));
			}
		}

		foreach (Property prop in iface.get_properties ()) {
			if (!prop.is_abstract) {
				continue;
			}

			if (prop.get_accessor != null) {
				var vfunc_entry = new CCodeMemberAccess.pointer (new CCodeIdentifier ("iface"), "get_" + prop.name);
				iface_block.add_statement (new CCodeExpressionStatement (new CCodeAssignment (vfunc_entry, new CCodeIdentifier (generate_dbus_proxy_property_get (main_iface, iface, prop)))));
			}
			if (prop.set_accessor != null) {
				var vfunc_entry = new CCodeMemberAccess.pointer (new CCodeIdentifier ("iface"), "set_" + prop.name);
				iface_block.add_statement (new CCodeExpressionStatement (new CCodeAssignment (vfunc_entry, new CCodeIdentifier (generate_dbus_proxy_property_set (main_iface, iface, prop)))));
			}
		}

		proxy_iface_init.modifiers = CCodeModifiers.STATIC;
		cfile.add_function_declaration (proxy_iface_init);
		proxy_iface_init.block = iface_block;
		cfile.add_function (proxy_iface_init);
	}

	string implement_interface (CCodeFunctionCall define_type, Interface main_iface, Interface iface) {
		string result = "";

		// also implement prerequisites
		foreach (var prereq in iface.get_prerequisites ()) {
			if (prereq.data_type is Interface) {
				result += implement_interface (define_type, main_iface, (Interface) prereq.data_type);
			}
		}

		result += "G_IMPLEMENT_INTERFACE (%s, %sproxy_%sinterface_init) ".printf (
			iface.get_upper_case_cname ("TYPE_"),
			main_iface.get_lower_case_cprefix (),
			iface.get_lower_case_cprefix ());
		return result;
	}

	public override void generate_interface_declaration (Interface iface, CCodeFile decl_space) {
		base.generate_interface_declaration (iface, decl_space);

		string dbus_iface_name = get_dbus_name (iface);
		if (dbus_iface_name == null) {
			return;
		}

		string get_type_name = "%sproxy_get_type".printf (iface.get_lower_case_cprefix ());

		if (add_symbol_declaration (decl_space, iface, get_type_name)) {
			return;
		}

		decl_space.add_type_declaration (new CCodeNewline ());
		var macro = "(%s ())".printf (get_type_name);
		decl_space.add_type_declaration (new CCodeMacroReplacement ("%s_PROXY".printf (iface.get_type_id ()), macro));

		// declare proxy_get_type function
		var proxy_get_type = new CCodeFunction (get_type_name, "GType");
		proxy_get_type.attributes = "G_GNUC_CONST";
		decl_space.add_function_declaration (proxy_get_type);
	}

	public override void visit_interface (Interface iface) {
		base.visit_interface (iface);

		string dbus_iface_name = get_dbus_name (iface);
		if (dbus_iface_name == null) {
			return;
		}

		cfile.add_include ("gio/gio.h");

		// create proxy class
		string cname = iface.get_cname () + "Proxy";
		string lower_cname = iface.get_lower_case_cprefix () + "proxy";

		cfile.add_type_declaration (new CCodeTypeDefinition ("GDBusProxy", new CCodeVariableDeclarator (cname)));
		cfile.add_type_declaration (new CCodeTypeDefinition ("GDBusProxyClass", new CCodeVariableDeclarator (cname + "Class")));

		var define_type = new CCodeFunctionCall (new CCodeIdentifier ("G_DEFINE_TYPE_EXTENDED"));
		define_type.add_argument (new CCodeIdentifier (cname));
		define_type.add_argument (new CCodeIdentifier (lower_cname));
		define_type.add_argument (new CCodeIdentifier ("G_TYPE_DBUS_PROXY"));
		define_type.add_argument (new CCodeConstant ("0"));
		define_type.add_argument (new CCodeIdentifier (implement_interface (define_type, iface, iface)));

		cfile.add_type_member_definition (define_type);

		var proxy_class_init = new CCodeFunction (lower_cname + "_class_init", "void");
		proxy_class_init.add_parameter (new CCodeParameter ("klass", cname + "Class*"));
		proxy_class_init.modifiers = CCodeModifiers.STATIC;
		proxy_class_init.block = new CCodeBlock ();
		var proxy_class = new CCodeFunctionCall (new CCodeIdentifier ("G_DBUS_PROXY_CLASS"));
		proxy_class.add_argument (new CCodeIdentifier ("klass"));
		proxy_class_init.block.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (proxy_class, "g_signal"), new CCodeIdentifier (lower_cname + "_g_signal"))));
		cfile.add_function (proxy_class_init);

		generate_signal_handler_function (iface);

		var proxy_instance_init = new CCodeFunction (lower_cname + "_init", "void");
		proxy_instance_init.add_parameter (new CCodeParameter ("self", cname + "*"));
		proxy_instance_init.modifiers = CCodeModifiers.STATIC;
		proxy_instance_init.block = new CCodeBlock ();
		cfile.add_function (proxy_instance_init);

		generate_proxy_interface_init (iface, iface);
	}

	public override void visit_method_call (MethodCall expr) {
		var mtype = expr.call.value_type as MethodType;
		bool bus_get_proxy_async = (mtype != null && mtype.method_symbol.get_cname () == "g_bus_get_proxy");
		bool bus_get_proxy_sync = (mtype != null && mtype.method_symbol.get_cname () == "g_bus_get_proxy_sync");
		bool conn_get_proxy_async = (mtype != null && mtype.method_symbol.get_cname () == "g_dbus_connection_get_proxy");
		bool conn_get_proxy_sync = (mtype != null && mtype.method_symbol.get_cname () == "g_dbus_connection_get_proxy_sync");
		if (!bus_get_proxy_async && !bus_get_proxy_sync && !conn_get_proxy_async && !conn_get_proxy_sync) {
			base.visit_method_call (expr);
			return;
		}

		var ma = (MemberAccess) expr.call;
		var type_arg = ma.get_type_arguments ().get (0);

		CCodeExpression proxy_type;
		CCodeExpression dbus_iface_name;

		var object_type = type_arg as ObjectType;
		if (object_type != null) {
			var iface = (Interface) object_type.type_symbol;

			if (get_dbus_name (iface) == null) {
				Report.error (expr.source_reference, "`%s' is not a D-Bus interface".printf (iface.get_full_name ()));
				return;
			}

			proxy_type = new CCodeIdentifier ("%s_PROXY".printf (iface.get_type_id ()));
			dbus_iface_name = new CCodeConstant ("\"%s\"".printf (get_dbus_name (iface)));
		} else {
			// use runtime type information for generic methods

			var quark = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
			quark.add_argument (new CCodeConstant ("\"vala-dbus-proxy-type\""));

			var get_qdata = new CCodeFunctionCall (new CCodeIdentifier ("g_type_get_qdata"));
			get_qdata.add_argument (get_type_id_expression (type_arg));
			get_qdata.add_argument (quark);

			proxy_type = new CCodeFunctionCall (new CCodeCastExpression (get_qdata, "GType (*) (void)"));

			quark = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
			quark.add_argument (new CCodeConstant ("\"vala-dbus-interface-name\""));

			get_qdata = new CCodeFunctionCall (new CCodeIdentifier ("g_type_get_qdata"));
			get_qdata.add_argument (get_type_id_expression (type_arg));
			get_qdata.add_argument (quark);

			dbus_iface_name = get_qdata;
		}

		var base_arg_index = 0;
		if (bus_get_proxy_async || bus_get_proxy_sync)
			base_arg_index = 1;

		var args = expr.get_argument_list ();
		Expression name = args.get (base_arg_index + 0);
		Expression object_path = args.get (base_arg_index + 1);
		Expression flags = args.get (base_arg_index + 2);
		Expression cancellable = args.get (base_arg_index + 3);

		// method can fail
		current_method_inner_error = true;

		CCodeFunctionCall ccall;
		if (bus_get_proxy_async || conn_get_proxy_async) {
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_async_initable_new_async"));
		} else {
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_initable_new"));
		}
		ccall.add_argument (proxy_type);
		if (bus_get_proxy_async || conn_get_proxy_async) {
			// I/O priority
			ccall.add_argument (new CCodeConstant ("0"));
		}
		ccall.add_argument (get_cvalue (cancellable));
		if (bus_get_proxy_async || conn_get_proxy_async) {
			if (expr.is_yield_expression) {
				// asynchronous call
				ccall.add_argument (new CCodeIdentifier (generate_ready_function (current_method)));
				ccall.add_argument (new CCodeIdentifier ("data"));
			} else {
				// begin
				Expression callback = args.get (base_arg_index + 4);
				ccall.add_argument (get_cvalue (callback));
				ccall.add_argument (get_delegate_target (callback));
			}
		} else {
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression ("_inner_error_")));
		}
		ccall.add_argument (new CCodeConstant ("\"g-flags\""));
		ccall.add_argument (get_cvalue (flags));
		ccall.add_argument (new CCodeConstant ("\"g-name\""));
		ccall.add_argument (get_cvalue (name));
		if (bus_get_proxy_async || bus_get_proxy_sync) {
			Expression bus_type = args.get (0);
			ccall.add_argument (new CCodeConstant ("\"g-bus-type\""));
			ccall.add_argument (get_cvalue (bus_type));
		} else {
			Expression connection = ma.inner;
			if (ma.member_name == "begin" && ma.inner.symbol_reference == ma.symbol_reference) {
				var inner_ma = (MemberAccess) ma.inner;
				connection = inner_ma.inner;
			}
			ccall.add_argument (new CCodeConstant ("\"g-connection\""));
			ccall.add_argument (get_cvalue (connection));
		}
		ccall.add_argument (new CCodeConstant ("\"g-object-path\""));
		ccall.add_argument (get_cvalue (object_path));
		ccall.add_argument (new CCodeConstant ("\"g-interface-name\""));
		ccall.add_argument (dbus_iface_name);
		ccall.add_argument (new CCodeConstant ("NULL"));

		if (bus_get_proxy_async || conn_get_proxy_async) {
			if (expr.is_yield_expression) {
				int state = next_coroutine_state++;

				ccode.add_assignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_state_"), new CCodeConstant (state.to_string ()));
				ccode.add_expression (ccall);
				ccode.add_return (new CCodeConstant ("FALSE"));
				ccode.add_label ("_state_%d".printf (state));

				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_async_initable_new_finish"));
				ccall.add_argument (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_source_object_"));
				// pass GAsyncResult stored in closure to finish function
				ccall.add_argument (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_res_"));
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression ("_inner_error_")));
			} else {
				// begin
				ccode.add_expression (ccall);
				return;
			}
		}

		var temp_var = get_temp_variable (expr.value_type, expr.value_type.value_owned);
		var temp_ref = get_variable_cexpression (temp_var.name);

		emit_temp_var (temp_var);

		ccode.add_assignment (temp_ref, ccall);
		set_cvalue (expr, temp_ref);
	}

	string generate_dbus_signal_handler (Signal sig, ObjectTypeSymbol sym) {
		string wrapper_name = "_dbus_handle_%s_%s".printf (sym.get_lower_case_cname (), sig.get_cname ());

		var function = new CCodeFunction (wrapper_name);
		function.modifiers = CCodeModifiers.STATIC;
		function.add_parameter (new CCodeParameter ("self", sym.get_cname () + "*"));
		function.add_parameter (new CCodeParameter ("parameters", "GVariant*"));

		push_function (function);

		ccode.add_declaration ("GVariantIter", new CCodeVariableDeclarator ("_arguments_iter"));

		var iter_init = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_iter_init"));
		iter_init.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_iter")));
		iter_init.add_argument (new CCodeIdentifier ("parameters"));
		ccode.add_expression (iter_init);

		var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_signal_emit_by_name"));
		ccall.add_argument (new CCodeIdentifier ("self"));
		ccall.add_argument (sig.get_canonical_cconstant ());

		foreach (Parameter param in sig.get_parameters ()) {
			var param_name = get_variable_cname (param.name);
			var owned_type = param.variable_type.copy ();
			owned_type.value_owned = true;

			ccode.add_declaration (owned_type.get_cname (), new CCodeVariableDeclarator.zero (param_name, default_value_for_type (param.variable_type, true)));

			var st = param.variable_type.data_type as Struct;
			if (st != null && !st.is_simple_type ()) {
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier (param_name)));
			} else {
				ccall.add_argument (new CCodeIdentifier (param_name));
			}

			if (param.variable_type is ArrayType) {
				var array_type = (ArrayType) param.variable_type;

				for (int dim = 1; dim <= array_type.rank; dim++) {
					string length_cname = get_parameter_array_length_cname (param, dim);

					ccode.add_declaration ("int", new CCodeVariableDeclarator (length_cname, new CCodeConstant ("0")));
					ccall.add_argument (new CCodeIdentifier (length_cname));
				}
			}

			read_expression (param.variable_type, new CCodeIdentifier ("_arguments_iter"), new CCodeIdentifier (param_name), param);
		}

		ccode.add_expression (ccall);

		foreach (Parameter param in sig.get_parameters ()) {
			var owned_type = param.variable_type.copy ();
			owned_type.value_owned = true;

			if (requires_destroy (owned_type)) {
				// keep local alive (symbol_reference is weak)
				var local = new LocalVariable (owned_type, param.name);
				ccode.add_expression (destroy_local (local));
			}
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return wrapper_name;
	}

	void generate_signal_handler_function (ObjectTypeSymbol sym) {
		var cfunc = new CCodeFunction (sym.get_lower_case_cprefix () + "proxy_g_signal", "void");
		cfunc.add_parameter (new CCodeParameter ("proxy", "GDBusProxy*"));
		cfunc.add_parameter (new CCodeParameter ("sender_name", "const gchar*"));
		cfunc.add_parameter (new CCodeParameter ("signal_name", "const gchar*"));
		cfunc.add_parameter (new CCodeParameter ("parameters", "GVariant*"));

		cfunc.modifiers |= CCodeModifiers.STATIC;

		cfile.add_function_declaration (cfunc);

		var block = new CCodeBlock ();
		cfunc.block = block;

		CCodeIfStatement clastif = null;

		foreach (Signal sig in sym.get_signals ()) {
			if (sig.access != SymbolAccessibility.PUBLIC) {
				continue;
			}

			cfile.add_include ("string.h");

			var ccheck = new CCodeFunctionCall (new CCodeIdentifier ("strcmp"));
			ccheck.add_argument (new CCodeIdentifier ("signal_name"));
			ccheck.add_argument (new CCodeConstant ("\"%s\"".printf (get_dbus_name_for_member (sig))));

			var callblock = new CCodeBlock ();

			var ccall = new CCodeFunctionCall (new CCodeIdentifier (generate_dbus_signal_handler (sig, sym)));
			ccall.add_argument (new CCodeCastExpression (new CCodeIdentifier ("proxy"), sym.get_cname () + "*"));
			ccall.add_argument (new CCodeIdentifier ("parameters"));

			callblock.add_statement (new CCodeExpressionStatement (ccall));

			var cif = new CCodeIfStatement (new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, ccheck, new CCodeConstant ("0")), callblock);
			if (clastif == null) {
				block.add_statement (cif);
			} else {
				clastif.false_statement = cif;
			}

			clastif = cif;
		}

		cfile.add_function (cfunc);
	}

	void generate_marshalling (Method m, CallType call_type, string? iface_name, string? method_name) {
		var gdbusproxy = new CCodeCastExpression (new CCodeIdentifier ("self"), "GDBusProxy *");

		var connection = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_get_connection"));
		connection.add_argument (gdbusproxy);

		bool uses_fd = dbus_method_uses_file_descriptor (m);
		if (uses_fd) {
			cfile.add_include ("gio/gunixfdlist.h");
		}

		if (call_type != CallType.FINISH) {
			var destination = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_get_name"));
			destination.add_argument (gdbusproxy);

			var interface_name = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_get_interface_name"));
			interface_name.add_argument (gdbusproxy);

			var object_path = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_get_object_path"));
			object_path.add_argument (gdbusproxy);

			var timeout = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_get_default_timeout"));
			timeout.add_argument (gdbusproxy);

			// register errors
			foreach (var error_type in m.get_error_types ()) {
				var errtype = (ErrorType) error_type;
				if (errtype.error_domain != null) {
					ccode.add_expression (new CCodeIdentifier (errtype.error_domain.get_upper_case_cname ()));
				}
			}

			// build D-Bus message

			ccode.add_declaration ("GDBusMessage", new CCodeVariableDeclarator ("*_message"));

			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_new_method_call"));
			ccall.add_argument (destination);
			ccall.add_argument (object_path);
			if (iface_name != null) {
				ccall.add_argument (new CCodeConstant ("\"%s\"".printf (iface_name)));
			} else {
				ccall.add_argument (interface_name);
			}
			ccall.add_argument (new CCodeConstant ("\"%s\"".printf (method_name)));
			ccode.add_assignment (new CCodeIdentifier ("_message"), ccall);

			ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_arguments"));
			ccode.add_declaration ("GVariantBuilder", new CCodeVariableDeclarator ("_arguments_builder"));

			var builder_init = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_init"));
			builder_init.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
			builder_init.add_argument (new CCodeIdentifier ("G_VARIANT_TYPE_TUPLE"));
			ccode.add_expression (builder_init);

			if (uses_fd) {
				ccode.add_declaration ("GUnixFDList", new CCodeVariableDeclarator ("*_fd_list"));
				ccode.add_assignment (new CCodeIdentifier ("_fd_list"), new CCodeFunctionCall (new CCodeIdentifier ("g_unix_fd_list_new")));
			}

			CCodeExpression cancellable = new CCodeConstant ("NULL");

			foreach (Parameter param in m.get_parameters ()) {
				if (param.direction == ParameterDirection.IN) {
					CCodeExpression expr = new CCodeIdentifier (get_variable_cname (param.name));
					if (param.variable_type.is_real_struct_type ()) {
						expr = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, expr);
					}

					if (param.variable_type is ObjectType && param.variable_type.data_type.get_full_name () == "GLib.Cancellable") {
						cancellable = expr;
						continue;
					}

					if (param.variable_type is ObjectType && param.variable_type.data_type.get_full_name () == "GLib.BusName") {
						// ignore BusName sender parameters
						continue;
					}

					send_dbus_value (param.variable_type, new CCodeIdentifier ("_arguments_builder"), expr, param);
				}
			}

			var builder_end = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_end"));
			builder_end.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
			ccode.add_assignment (new CCodeIdentifier ("_arguments"), builder_end);

			var set_body = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_set_body"));
			set_body.add_argument (new CCodeIdentifier ("_message"));
			set_body.add_argument (new CCodeIdentifier ("_arguments"));
			ccode.add_expression (set_body);

			if (uses_fd) {
				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_set_unix_fd_list"));
				ccall.add_argument (new CCodeIdentifier ("_message"));
				ccall.add_argument (new CCodeIdentifier ("_fd_list"));
				ccode.add_expression (ccall);

				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_object_unref"));
				ccall.add_argument (new CCodeIdentifier ("_fd_list"));
				ccode.add_expression (ccall);
			}

			// send D-Bus message

			if (call_type == CallType.SYNC) {
				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_connection_send_message_with_reply_sync"));
				ccall.add_argument (connection);
				ccall.add_argument (new CCodeIdentifier ("_message"));
				ccall.add_argument (new CCodeConstant ("G_DBUS_SEND_MESSAGE_FLAGS_NONE"));
				ccall.add_argument (timeout);
				ccall.add_argument (new CCodeConstant ("NULL"));
				ccall.add_argument (cancellable);
				ccall.add_argument (new CCodeIdentifier ("error"));
				ccode.add_assignment (new CCodeIdentifier ("_reply_message"), ccall);
			} else if (call_type == CallType.NO_REPLY) {
				var set_flags = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_set_flags"));
				set_flags.add_argument (new CCodeIdentifier ("_message"));
				set_flags.add_argument (new CCodeConstant ("G_DBUS_MESSAGE_FLAGS_NO_REPLY_EXPECTED"));
				ccode.add_expression (set_flags);

				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_connection_send_message"));
				ccall.add_argument (connection);
				ccall.add_argument (new CCodeIdentifier ("_message"));
				ccall.add_argument (new CCodeConstant ("G_DBUS_SEND_MESSAGE_FLAGS_NONE"));
				ccall.add_argument (new CCodeConstant ("NULL"));
				ccall.add_argument (new CCodeIdentifier ("error"));
				ccode.add_expression (ccall);
			} else if (call_type == CallType.ASYNC) {
				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_connection_send_message_with_reply"));
				ccall.add_argument (connection);
				ccall.add_argument (new CCodeIdentifier ("_message"));
				ccall.add_argument (new CCodeConstant ("G_DBUS_SEND_MESSAGE_FLAGS_NONE"));
				ccall.add_argument (timeout);
				ccall.add_argument (new CCodeConstant ("NULL"));
				ccall.add_argument (cancellable);

				// use wrapper as source_object wouldn't be correct otherwise
				ccall.add_argument (new CCodeIdentifier (generate_async_callback_wrapper ()));
				var res_wrapper = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_new"));
				res_wrapper.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "GObject *"));
				res_wrapper.add_argument (new CCodeIdentifier ("_callback_"));
				res_wrapper.add_argument (new CCodeIdentifier ("_user_data_"));
				res_wrapper.add_argument (new CCodeConstant ("NULL"));
				ccall.add_argument (res_wrapper);

				ccode.add_expression (ccall);
			}

			// free D-Bus message

			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_object_unref"));
			ccall.add_argument (new CCodeIdentifier ("_message"));
			ccode.add_expression (ccall);
		} else {
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_connection_send_message_with_reply_finish"));
			ccall.add_argument (connection);

			// unwrap async result
			var inner_res = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_get_op_res_gpointer"));
			inner_res.add_argument (new CCodeCastExpression (new CCodeIdentifier ("_res_"), "GSimpleAsyncResult *"));
			ccall.add_argument (inner_res);

			ccall.add_argument (new CCodeConstant ("error"));
			ccode.add_assignment (new CCodeIdentifier ("_reply_message"), ccall);
		}

		if (call_type == CallType.SYNC || call_type == CallType.FINISH) {
			ccode.add_declaration ("GDBusMessage", new CCodeVariableDeclarator ("*_reply_message"));

			var unref_reply = new CCodeFunctionCall (new CCodeIdentifier ("g_object_unref"));
			unref_reply.add_argument (new CCodeIdentifier ("_reply_message"));

			// return on io error
			var reply_is_null = new CCodeUnaryExpression (CCodeUnaryOperator.LOGICAL_NEGATION, new CCodeIdentifier ("_reply_message"));
			ccode.open_if (reply_is_null);
			return_default_value (m.return_type);
			ccode.close ();

			// return on remote error
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_to_gerror"));
			ccall.add_argument (new CCodeIdentifier ("_reply_message"));
			ccall.add_argument (new CCodeIdentifier ("error"));
			ccode.open_if (ccall);
			ccode.add_expression (unref_reply);
			return_default_value (m.return_type);
			ccode.close ();

			bool has_result = !(m.return_type is VoidType);

			if (uses_fd) {
				ccode.add_declaration ("gint", new CCodeVariableDeclarator.zero ("_fd_index", new CCodeConstant ("0")));
			}

			foreach (Parameter param in m.get_parameters ()) {
				if (param.direction == ParameterDirection.OUT) {
					has_result = true;
				}
			}

			if (has_result) {
				ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_reply"));
				ccode.add_declaration ("GVariantIter", new CCodeVariableDeclarator ("_reply_iter"));

				ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_message_get_body"));
				ccall.add_argument (new CCodeIdentifier ("_reply_message"));
				ccode.add_assignment (new CCodeIdentifier ("_reply"), ccall);

				var iter_init = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_iter_init"));
				iter_init.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_reply_iter")));
				iter_init.add_argument (new CCodeIdentifier ("_reply"));
				ccode.add_expression (iter_init);

				foreach (Parameter param in m.get_parameters ()) {
					if (param.direction == ParameterDirection.OUT) {
						ccode.add_declaration (param.variable_type.get_cname (), new CCodeVariableDeclarator ("_" + param.name));

						var array_type = param.variable_type as ArrayType;

						if (array_type != null) {
							for (int dim = 1; dim <= array_type.rank; dim++) {
								ccode.add_declaration ("int", new CCodeVariableDeclarator ("_%s_length%d".printf (param.name, dim), new CCodeConstant ("0")));
							}
						}

						var target = new CCodeIdentifier ("_" + param.name);
						bool may_fail;
						receive_dbus_value (param.variable_type, new CCodeIdentifier ("_reply_message"), new CCodeIdentifier ("_reply_iter"), target, param, new CCodeIdentifier ("error"), out may_fail);

						// TODO check that parameter is not NULL (out parameters are optional)
						// free value if parameter is NULL
						ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier (get_variable_cname (param.name))), target);

						if (array_type != null) {
							for (int dim = 1; dim <= array_type.rank; dim++) {
								// TODO check that parameter is not NULL (out parameters are optional)
								ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("%s_length%d".printf (param.name, dim))), new CCodeIdentifier ("_%s_length%d".printf (param.name, dim)));
							}
						}

						if (may_fail) {
							ccode.open_if (new CCodeBinaryExpression (CCodeBinaryOperator.AND, new CCodeIdentifier ("error"), new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("error"))));
							ccode.add_expression (unref_reply);
							return_default_value (m.return_type);
							ccode.close ();
						}
					}
				}

				if (!(m.return_type is VoidType)) {
					if (m.return_type.is_real_non_null_struct_type ()) {
						var target = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("result"));
						receive_dbus_value (m.return_type, new CCodeIdentifier ("_reply_message"), new CCodeIdentifier ("_reply_iter"), target, m);
					} else {
						ccode.add_declaration (m.return_type.get_cname (), new CCodeVariableDeclarator ("_result"));

						var array_type = m.return_type as ArrayType;

						if (array_type != null) {
							for (int dim = 1; dim <= array_type.rank; dim++) {
								ccode.add_declaration ("int", new CCodeVariableDeclarator ("_result_length%d".printf (dim), new CCodeConstant ("0")));
							}
						}

						bool may_fail;
						receive_dbus_value (m.return_type, new CCodeIdentifier ("_reply_message"), new CCodeIdentifier ("_reply_iter"), new CCodeIdentifier ("_result"), m, new CCodeIdentifier ("error"), out may_fail);

						if (array_type != null) {
							for (int dim = 1; dim <= array_type.rank; dim++) {
								// TODO check that parameter is not NULL (out parameters are optional)
								ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("result_length%d".printf (dim))), new CCodeIdentifier ("_result_length%d".printf (dim)));
							}
						}

						if (may_fail) {
							ccode.open_if (new CCodeBinaryExpression (CCodeBinaryOperator.AND, new CCodeIdentifier ("error"), new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("error"))));
							ccode.add_expression (unref_reply);
							return_default_value (m.return_type);
							ccode.close ();
						}
					}
				}
			}

			ccode.add_expression (unref_reply);

			if (!(m.return_type is VoidType || m.return_type.is_real_non_null_struct_type ())) {
				ccode.add_return (new CCodeIdentifier ("_result"));
			}
		}
	}

	string generate_dbus_proxy_method (Interface main_iface, Interface iface, Method m) {
		string proxy_name = "%sproxy_%s".printf (main_iface.get_lower_case_cprefix (), m.name);

		string dbus_iface_name = get_dbus_name (iface);

		bool no_reply = is_dbus_no_reply (m);

		var function = new CCodeFunction (proxy_name);
		function.modifiers = CCodeModifiers.STATIC;

		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		generate_cparameters (m, cfile, cparam_map, function);

		push_function (function);

		generate_marshalling (m, no_reply ? CallType.NO_REPLY : CallType.SYNC, dbus_iface_name, get_dbus_name_for_member (m));

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return proxy_name;
	}

	string generate_async_dbus_proxy_method (Interface main_iface, Interface iface, Method m) {
		string proxy_name = "%sproxy_%s_async".printf (main_iface.get_lower_case_cprefix (), m.name);

		string dbus_iface_name = get_dbus_name (iface);

		var function = new CCodeFunction (proxy_name, "void");
		function.modifiers = CCodeModifiers.STATIC;

		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		cparam_map.set (get_param_pos (-1), new CCodeParameter ("_callback_", "GAsyncReadyCallback"));
		cparam_map.set (get_param_pos (-0.9), new CCodeParameter ("_user_data_", "gpointer"));

		generate_cparameters (m, cfile, cparam_map, function, null, null, null, 1);

		push_function (function);

		generate_marshalling (m, CallType.ASYNC, dbus_iface_name, get_dbus_name_for_member (m));

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return proxy_name;
	}

	string generate_finish_dbus_proxy_method (Interface main_iface, Interface iface, Method m) {
		string proxy_name = "%sproxy_%s_finish".printf (main_iface.get_lower_case_cprefix (), m.name);

		var function = new CCodeFunction (proxy_name);
		function.modifiers = CCodeModifiers.STATIC;

		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		cparam_map.set (get_param_pos (0.1), new CCodeParameter ("_res_", "GAsyncResult*"));

		generate_cparameters (m, cfile, cparam_map, function, null, null, null, 2);

		push_function (function);

		generate_marshalling (m, CallType.FINISH, null, null);

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return proxy_name;
	}

	string generate_dbus_proxy_property_get (Interface main_iface, Interface iface, Property prop) {
		string proxy_name = "%sdbus_proxy_get_%s".printf (main_iface.get_lower_case_cprefix (), prop.name);

		string dbus_iface_name = get_dbus_name (iface);

		var owned_type = prop.get_accessor.value_type.copy ();
		owned_type.value_owned = true;
		if (owned_type.is_disposable () && !prop.get_accessor.value_type.value_owned) {
			Report.error (prop.get_accessor.value_type.source_reference, "Properties used in D-Bus clients require owned get accessor");
		}

		var array_type = prop.get_accessor.value_type as ArrayType;

		var function = new CCodeFunction (proxy_name);
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("self", "%s*".printf (iface.get_cname ())));

		if (prop.property_type.is_real_non_null_struct_type ()) {
			function.add_parameter (new CCodeParameter ("result", "%s*".printf (prop.get_accessor.value_type.get_cname ())));
		} else {
			if (array_type != null) {
				for (int dim = 1; dim <= array_type.rank; dim++) {
					function.add_parameter (new CCodeParameter ("result_length%d".printf (dim), "int*"));
				}
			}

			function.return_type = prop.get_accessor.value_type.get_cname ();
		}

		push_function (function);

		ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_inner_reply"));

		// first try cached value
		var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_get_cached_property"));
		ccall.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "GDBusProxy *"));
		ccall.add_argument (new CCodeConstant ("\"%s\"".printf (get_dbus_name_for_member (prop))));
		ccode.add_assignment (new CCodeIdentifier ("_inner_reply"), ccall);

		// if not successful, retrieve value via D-Bus
		ccode.open_if (new CCodeUnaryExpression (CCodeUnaryOperator.LOGICAL_NEGATION, new CCodeIdentifier ("_inner_reply")));

		ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_arguments"));
		ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_reply"));
		ccode.add_declaration ("GVariantBuilder", new CCodeVariableDeclarator ("_arguments_builder"));

		var builder_init = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_init"));
		builder_init.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
		builder_init.add_argument (new CCodeIdentifier ("G_VARIANT_TYPE_TUPLE"));
		ccode.add_expression (builder_init);

		// interface name
		write_expression (string_type, new CCodeIdentifier ("_arguments_builder"), new CCodeConstant ("\"%s\"".printf (dbus_iface_name)), null);
		// property name
		write_expression (string_type, new CCodeIdentifier ("_arguments_builder"), new CCodeConstant ("\"%s\"".printf (get_dbus_name_for_member (prop))), null);

		var builder_end = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_end"));
		builder_end.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
		ccode.add_assignment (new CCodeIdentifier ("_arguments"), builder_end);

		ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_call_sync"));
		ccall.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "GDBusProxy *"));
		ccall.add_argument (new CCodeConstant ("\"org.freedesktop.DBus.Properties.Get\""));
		ccall.add_argument (new CCodeIdentifier ("_arguments"));
		ccall.add_argument (new CCodeConstant ("G_DBUS_CALL_FLAGS_NONE"));
		ccall.add_argument (get_dbus_timeout (prop));
		ccall.add_argument (new CCodeConstant ("NULL"));
		ccall.add_argument (new CCodeConstant ("NULL"));

		ccode.add_assignment (new CCodeIdentifier ("_reply"), ccall);

		// return on error
		ccode.open_if (new CCodeUnaryExpression (CCodeUnaryOperator.LOGICAL_NEGATION, new CCodeIdentifier ("_reply")));
		return_default_value (prop.property_type);
		ccode.close ();

		var get_variant = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_get"));
		get_variant.add_argument (new CCodeIdentifier ("_reply"));
		get_variant.add_argument (new CCodeConstant ("\"(v)\""));
		get_variant.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_inner_reply")));
		ccode.add_expression (get_variant);

		var unref_reply = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_unref"));
		unref_reply.add_argument (new CCodeIdentifier ("_reply"));
		ccode.add_expression (unref_reply);

		ccode.close ();

		if (prop.property_type.is_real_non_null_struct_type ()) {
			var target = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("result"));
			var result = deserialize_expression (prop.get_accessor.value_type, new CCodeIdentifier ("_inner_reply"), target);
			ccode.add_assignment (target, result);
		} else {
			ccode.add_declaration (prop.get_accessor.value_type.get_cname (), new CCodeVariableDeclarator ("_result"));

			if (array_type != null) {
				for (int dim = 1; dim <= array_type.rank; dim++) {
					ccode.add_declaration ("int", new CCodeVariableDeclarator ("_result_length%d".printf (dim), new CCodeConstant ("0")));
				}
			}

			var result = deserialize_expression (prop.get_accessor.value_type, new CCodeIdentifier ("_inner_reply"), new CCodeIdentifier ("_result"));
			ccode.add_assignment (new CCodeIdentifier ("_result"), result);

			if (array_type != null) {
				for (int dim = 1; dim <= array_type.rank; dim++) {
					// TODO check that parameter is not NULL (out parameters are optional)
					ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("result_length%d".printf (dim))), new CCodeIdentifier ("_result_length%d".printf (dim)));
				}
			}
		}

		unref_reply = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_unref"));
		unref_reply.add_argument (new CCodeIdentifier ("_inner_reply"));
		ccode.add_expression (unref_reply);

		if (prop.property_type.is_real_non_null_struct_type ()) {
			ccode.add_return ();
		} else {
			ccode.add_return (new CCodeIdentifier ("_result"));
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return proxy_name;
	}

	string generate_dbus_proxy_property_set (Interface main_iface, Interface iface, Property prop) {
		string proxy_name = "%sdbus_proxy_set_%s".printf (main_iface.get_lower_case_cprefix (), prop.name);

		string dbus_iface_name = get_dbus_name (iface);

		var array_type = prop.set_accessor.value_type as ArrayType;

		var function = new CCodeFunction (proxy_name);
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("self", "%s*".printf (iface.get_cname ())));

		if (prop.property_type.is_real_non_null_struct_type ()) {
			function.add_parameter (new CCodeParameter ("value", "%s*".printf (prop.set_accessor.value_type.get_cname ())));
		} else {
			function.add_parameter (new CCodeParameter ("value", prop.set_accessor.value_type.get_cname ()));

			if (array_type != null) {
				for (int dim = 1; dim <= array_type.rank; dim++) {
					function.add_parameter (new CCodeParameter ("value_length%d".printf (dim), "int"));
				}
			}
		}

		push_function (function);

		ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_arguments"));
		ccode.add_declaration ("GVariant", new CCodeVariableDeclarator ("*_reply"));

		ccode.add_declaration ("GVariantBuilder", new CCodeVariableDeclarator ("_arguments_builder"));

		var builder_init = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_init"));
		builder_init.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
		builder_init.add_argument (new CCodeIdentifier ("G_VARIANT_TYPE_TUPLE"));
		ccode.add_expression (builder_init);

		// interface name
		write_expression (string_type, new CCodeIdentifier ("_arguments_builder"), new CCodeConstant ("\"%s\"".printf (dbus_iface_name)), null);
		// property name
		write_expression (string_type, new CCodeIdentifier ("_arguments_builder"), new CCodeConstant ("\"%s\"".printf (get_dbus_name_for_member (prop))), null);

		// property value (as variant)
		var builder_open = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_open"));
		builder_open.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
		builder_open.add_argument (new CCodeIdentifier ("G_VARIANT_TYPE_VARIANT"));
		ccode.add_expression (builder_open);

		if (prop.property_type.is_real_non_null_struct_type ()) {
			write_expression (prop.set_accessor.value_type, new CCodeIdentifier ("_arguments_builder"), new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("value")), prop);
		} else {
			write_expression (prop.set_accessor.value_type, new CCodeIdentifier ("_arguments_builder"), new CCodeIdentifier ("value"), prop);
		}

		var builder_close = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_close"));
		builder_close.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
		ccode.add_expression (builder_close);

		var builder_end = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_builder_end"));
		builder_end.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("_arguments_builder")));
		ccode.add_assignment (new CCodeIdentifier ("_arguments"), builder_end);

		var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_dbus_proxy_call_sync"));
		ccall.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "GDBusProxy *"));
		ccall.add_argument (new CCodeConstant ("\"org.freedesktop.DBus.Properties.Set\""));
		ccall.add_argument (new CCodeIdentifier ("_arguments"));
		ccall.add_argument (new CCodeConstant ("G_DBUS_CALL_FLAGS_NONE"));
		ccall.add_argument (get_dbus_timeout (prop));
		ccall.add_argument (new CCodeConstant ("NULL"));
		ccall.add_argument (new CCodeConstant ("NULL"));

		ccode.add_assignment (new CCodeIdentifier ("_reply"), ccall);

		// return on error
		ccode.open_if (new CCodeUnaryExpression (CCodeUnaryOperator.LOGICAL_NEGATION, new CCodeIdentifier ("_reply")));
		ccode.add_return ();
		ccode.close ();

		var unref_reply = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_unref"));
		unref_reply.add_argument (new CCodeIdentifier ("_reply"));
		ccode.add_expression (unref_reply);

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return proxy_name;
	}

	public override void register_dbus_info (CCodeBlock block, ObjectTypeSymbol sym) {
		if (!(sym is Interface)) {
			return;
		}

		string dbus_iface_name = get_dbus_name (sym);
		if (dbus_iface_name == null) {
			return;
		}

		var quark = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
		quark.add_argument (new CCodeConstant ("\"vala-dbus-proxy-type\""));

		var proxy_type = new CCodeIdentifier (sym.get_lower_case_cprefix () + "proxy_get_type");

		var set_qdata = new CCodeFunctionCall (new CCodeIdentifier ("g_type_set_qdata"));
		set_qdata.add_argument (new CCodeIdentifier ("%s_type_id".printf (sym.get_lower_case_cname (null))));
		set_qdata.add_argument (quark);
		set_qdata.add_argument (new CCodeCastExpression (proxy_type, "void*"));

		block.add_statement (new CCodeExpressionStatement (set_qdata));

		quark = new CCodeFunctionCall (new CCodeIdentifier ("g_quark_from_static_string"));
		quark.add_argument (new CCodeConstant ("\"vala-dbus-interface-name\""));

		set_qdata = new CCodeFunctionCall (new CCodeIdentifier ("g_type_set_qdata"));
		set_qdata.add_argument (new CCodeIdentifier ("%s_type_id".printf (sym.get_lower_case_cname (null))));
		set_qdata.add_argument (quark);
		set_qdata.add_argument (new CCodeConstant ("\"%s\"".printf (dbus_iface_name)));

		block.add_statement (new CCodeExpressionStatement (set_qdata));
	}
}
