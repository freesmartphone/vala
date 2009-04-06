/* gtksourceview-2.0.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "Gtk", lower_case_cprefix = "gtk_")]
namespace Gtk {
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceBuffer : Gtk.TextBuffer {
		public bool backward_iter_to_source_mark (Gtk.TextIter iter, string category);
		public void begin_not_undoable_action ();
		public unowned Gtk.SourceMark create_source_mark (string name, string category, Gtk.TextIter where);
		public void end_not_undoable_action ();
		public void ensure_highlight (Gtk.TextIter start, Gtk.TextIter end);
		public bool forward_iter_to_source_mark (Gtk.TextIter iter, string category);
		public bool get_highlight_matching_brackets ();
		public bool get_highlight_syntax ();
		public unowned Gtk.SourceLanguage get_language ();
		public int get_max_undo_levels ();
		public unowned GLib.SList get_source_marks_at_iter (Gtk.TextIter iter, string category);
		public unowned GLib.SList get_source_marks_at_line (int line, string category);
		public unowned Gtk.SourceStyleScheme get_style_scheme ();
		[CCode (has_construct_function = false)]
		public SourceBuffer (Gtk.TextTagTable table);
		public void redo ();
		public void remove_source_marks (Gtk.TextIter start, Gtk.TextIter end, string category);
		public void set_highlight_matching_brackets (bool highlight);
		public void set_highlight_syntax (bool highlight);
		public void set_language (Gtk.SourceLanguage language);
		public void set_max_undo_levels (int max_undo_levels);
		public void set_style_scheme (Gtk.SourceStyleScheme scheme);
		public void undo ();
		[CCode (has_construct_function = false)]
		public SourceBuffer.with_language (Gtk.SourceLanguage language);
		[NoAccessorMethod]
		public bool can_redo { get; }
		[NoAccessorMethod]
		public bool can_undo { get; }
		public bool highlight_matching_brackets { get; set; }
		public bool highlight_syntax { get; set; }
		public Gtk.SourceLanguage language { get; set; }
		public int max_undo_levels { get; set; }
		public Gtk.SourceStyleScheme style_scheme { get; set; }
		public virtual signal void source_mark_updated (Gtk.TextMark p0);
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceLanguage : GLib.Object {
		public unowned string get_globs ();
		public bool get_hidden ();
		public unowned string get_id ();
		public unowned string get_metadata (string name);
		public unowned string get_mime_types ();
		public unowned string get_name ();
		public unowned string get_section ();
		public unowned string get_style_ids ();
		public unowned string get_style_name (string style_id);
		public bool hidden { get; }
		public string id { get; }
		public string name { get; }
		public string section { get; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcelanguagemanager.h")]
	public class SourceLanguageManager : GLib.Object {
		public static unowned Gtk.SourceLanguageManager get_default ();
		public unowned Gtk.SourceLanguage get_language (string id);
		public unowned string get_language_ids ();
		public unowned string get_search_path ();
		[CCode (has_construct_function = false)]
		public SourceLanguageManager ();
		public void set_search_path (string dirs);
		public string[] language_ids { get; }
		public string[] search_path { get; set; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceMark : Gtk.TextMark {
		public unowned string get_category ();
		[CCode (has_construct_function = false)]
		public SourceMark (string name, string category);
		public unowned Gtk.SourceMark next (string category);
		public unowned Gtk.SourceMark prev (string category);
		public string category { get; construct; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourcePrintCompositor : GLib.Object {
		public void draw_page (Gtk.PrintContext context, int page_nr);
		[CCode (has_construct_function = false)]
		public SourcePrintCompositor.from_view (Gtk.SourceView view);
		public unowned string get_body_font_name ();
		public double get_bottom_margin (Gtk.Unit unit);
		public unowned Gtk.SourceBuffer get_buffer ();
		public unowned string get_footer_font_name ();
		public unowned string get_header_font_name ();
		public bool get_highlight_syntax ();
		public double get_left_margin (Gtk.Unit unit);
		public unowned string get_line_numbers_font_name ();
		public int get_n_pages ();
		public double get_pagination_progress ();
		public bool get_print_footer ();
		public bool get_print_header ();
		public uint get_print_line_numbers ();
		public double get_right_margin (Gtk.Unit unit);
		public uint get_tab_width ();
		public double get_top_margin (Gtk.Unit unit);
		public Gtk.WrapMode get_wrap_mode ();
		[CCode (has_construct_function = false)]
		public SourcePrintCompositor (Gtk.SourceBuffer buffer);
		public bool paginate (Gtk.PrintContext context);
		public void set_body_font_name (string font_name);
		public void set_bottom_margin (double margin, Gtk.Unit unit);
		public void set_footer_font_name (string font_name);
		public void set_footer_format (bool separator, string left, string center, string right);
		public void set_header_font_name (string font_name);
		public void set_header_format (bool separator, string left, string center, string right);
		public void set_highlight_syntax (bool highlight);
		public void set_left_margin (double margin, Gtk.Unit unit);
		public void set_line_numbers_font_name (string font_name);
		public void set_print_footer (bool print);
		public void set_print_header (bool print);
		public void set_print_line_numbers (uint interval);
		public void set_right_margin (double margin, Gtk.Unit unit);
		public void set_tab_width (uint width);
		public void set_top_margin (double margin, Gtk.Unit unit);
		public void set_wrap_mode (Gtk.WrapMode wrap_mode);
		public string body_font_name { get; set; }
		public Gtk.SourceBuffer buffer { get; construct; }
		public string footer_font_name { get; set; }
		public string header_font_name { get; set; }
		public bool highlight_syntax { get; set; }
		public string line_numbers_font_name { get; set; }
		public int n_pages { get; }
		public bool print_footer { get; set; }
		public bool print_header { get; set; }
		public uint print_line_numbers { get; set; }
		public uint tab_width { get; set; }
		public Gtk.WrapMode wrap_mode { get; set; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceStyle : GLib.Object {
		public unowned Gtk.SourceStyle copy ();
		[NoAccessorMethod]
		public string background { owned get; construct; }
		[NoAccessorMethod]
		public bool background_set { get; construct; }
		[NoAccessorMethod]
		public bool bold { get; construct; }
		[NoAccessorMethod]
		public bool bold_set { get; construct; }
		[NoAccessorMethod]
		public string foreground { owned get; construct; }
		[NoAccessorMethod]
		public bool foreground_set { get; construct; }
		[NoAccessorMethod]
		public bool italic { get; construct; }
		[NoAccessorMethod]
		public bool italic_set { get; construct; }
		[NoAccessorMethod]
		public string line_background { owned get; construct; }
		[NoAccessorMethod]
		public bool line_background_set { get; construct; }
		[NoAccessorMethod]
		public bool strikethrough { get; construct; }
		[NoAccessorMethod]
		public bool strikethrough_set { get; construct; }
		[NoAccessorMethod]
		public bool underline { get; construct; }
		[NoAccessorMethod]
		public bool underline_set { get; construct; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceStyleScheme : GLib.Object {
		public unowned string get_authors ();
		public unowned string get_description ();
		public unowned string get_filename ();
		public unowned string get_id ();
		public unowned string get_name ();
		public unowned Gtk.SourceStyle get_style (string style_id);
		public string description { get; }
		public string filename { get; }
		public string id { get; construct; }
		public string name { get; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcestyleschememanager.h")]
	public class SourceStyleSchemeManager : GLib.Object {
		public void append_search_path (string path);
		public void force_rescan ();
		public static unowned Gtk.SourceStyleSchemeManager get_default ();
		public unowned Gtk.SourceStyleScheme get_scheme (string scheme_id);
		[CCode (array_length = false, array_null_terminated = true)]
		public unowned string[] get_scheme_ids ();
		[CCode (array_length = false, array_null_terminated = true)]
		public unowned string[] get_search_path ();
		[CCode (has_construct_function = false)]
		public SourceStyleSchemeManager ();
		public void prepend_search_path (string path);
		public void set_search_path (string path);
		public string[] scheme_ids { get; }
		public string[] search_path { get; set; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceView : Gtk.TextView, Atk.Implementor, Gtk.Buildable {
		public bool get_auto_indent ();
		public bool get_highlight_current_line ();
		public bool get_indent_on_tab ();
		public int get_indent_width ();
		public bool get_insert_spaces_instead_of_tabs ();
		public unowned Gdk.Pixbuf get_mark_category_pixbuf (string category);
		public int get_mark_category_priority (string category);
		public uint get_right_margin_position ();
		public bool get_show_line_marks ();
		public bool get_show_line_numbers ();
		public bool get_show_right_margin ();
		public Gtk.SourceSmartHomeEndType get_smart_home_end ();
		public uint get_tab_width ();
		[CCode (type = "GtkWidget*", has_construct_function = false)]
		public SourceView ();
		public void set_auto_indent (bool enable);
		public void set_highlight_current_line (bool show);
		public void set_indent_on_tab (bool enable);
		public void set_indent_width (int width);
		public void set_insert_spaces_instead_of_tabs (bool enable);
		public void set_mark_category_pixbuf (string category, Gdk.Pixbuf pixbuf);
		public void set_mark_category_priority (string category, int priority);
		public void set_right_margin_position (uint pos);
		public void set_show_line_marks (bool show);
		public void set_show_line_numbers (bool show);
		public void set_show_right_margin (bool show);
		public void set_smart_home_end (Gtk.SourceSmartHomeEndType smart_he);
		public void set_tab_width (uint width);
		[CCode (type = "GtkWidget*", has_construct_function = false)]
		public SourceView.with_buffer (Gtk.SourceBuffer buffer);
		public bool auto_indent { get; set; }
		public bool highlight_current_line { get; set; }
		public bool indent_on_tab { get; set; }
		public int indent_width { get; set; }
		public bool insert_spaces_instead_of_tabs { get; set; }
		public uint right_margin_position { get; set; }
		public bool show_line_marks { get; set; }
		public bool show_line_numbers { get; set; }
		public bool show_right_margin { get; set; }
		public Gtk.SourceSmartHomeEndType smart_home_end { get; set; }
		public uint tab_width { get; set; }
		public virtual signal void redo ();
		public virtual signal void undo ();
	}
	[CCode (cprefix = "GTK_SOURCE_SEARCH_", has_type_id = "0", cheader_filename = "gtksourceview/gtksourceiter.h")]
	[Flags]
	public enum SourceSearchFlags {
		VISIBLE_ONLY,
		TEXT_ONLY,
		CASE_INSENSITIVE
	}
	[CCode (cprefix = "GTK_SOURCE_SMART_HOME_END_", has_type_id = "0", cheader_filename = "gtksourceview/gtksourceview.h")]
	public enum SourceSmartHomeEndType {
		DISABLED,
		BEFORE,
		AFTER,
		ALWAYS
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public static bool source_iter_backward_search (Gtk.TextIter iter, string str, Gtk.SourceSearchFlags flags, out Gtk.TextIter match_start, out Gtk.TextIter match_end, Gtk.TextIter? limit);
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public static bool source_iter_forward_search (Gtk.TextIter iter, string str, Gtk.SourceSearchFlags flags, out Gtk.TextIter match_start, out Gtk.TextIter match_end, Gtk.TextIter? limit);
}
