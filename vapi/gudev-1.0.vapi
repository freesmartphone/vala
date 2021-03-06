/* gudev-1.0.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "GUdev", lower_case_cprefix = "g_udev_")]
namespace GUdev {
	[CCode (cheader_filename = "gudev/gudev.h")]
	public class Client : GLib.Object {
		[CCode (has_construct_function = false)]
		public Client ([CCode (array_length = false)] string[]? subsystems);
		public unowned GUdev.Device? query_by_device_file (string device_file);
		public unowned GUdev.Device? query_by_device_number (GUdev.DeviceType type, GUdev.DeviceNumber number);
		public GLib.List<GUdev.Device> query_by_subsystem (string? subsystem);
		public unowned GUdev.Device? query_by_subsystem_and_name (string subsystem, string name);
		public unowned GUdev.Device? query_by_sysfs_path (string sysfs_path);
		[NoWrapper]
		public virtual void reserved1 ();
		[NoWrapper]
		public virtual void reserved2 ();
		[NoWrapper]
		public virtual void reserved3 ();
		[NoWrapper]
		public virtual void reserved4 ();
		[NoWrapper]
		public virtual void reserved5 ();
		[NoWrapper]
		public virtual void reserved6 ();
		[NoWrapper]
		public virtual void reserved7 ();
		[NoWrapper]
		public virtual void reserved8 ();
		[NoAccessorMethod]
		[CCode (array_length = false, array_null_terminated = true)]
		public string[] subsystems { owned get; construct; }
		public virtual signal void uevent (string action, GUdev.Device device);
	}
	[CCode (cheader_filename = "gudev/gudev.h")]
	public class Device : GLib.Object {
		[CCode (has_construct_function = false)]
		protected Device ();
		public unowned string get_action ();
		public unowned string? get_device_file ();
		[CCode (array_length = false)]
		public unowned string[] get_device_file_symlinks ();
		public GUdev.DeviceNumber get_device_number ();
		public GUdev.DeviceType get_device_type ();
		public unowned string get_devtype ();
		public unowned string? get_driver ();
		public unowned string get_name ();
		public unowned string get_number ();
		public unowned GUdev.Device? get_parent ();
		public unowned GUdev.Device? get_parent_with_subsystem (string subsystem, string? devtype);
		public unowned string? get_property (string key);
		public bool get_property_as_boolean (string key);
		public double get_property_as_double (string key);
		public int get_property_as_int (string key);
		[CCode (array_length = false)]
		public unowned string?[] get_property_as_strv (string key);
		public uint64 get_property_as_uint64 (string key);
		[CCode (array_length = false, array_null_terminated = true)]
		public unowned string?[] get_property_keys ();
		public uint64 get_seqnum ();
		public unowned string get_subsystem ();
		public unowned string? get_sysfs_attr (string name);
		public bool get_sysfs_attr_as_boolean (string name);
		public double get_sysfs_attr_as_double (string name);
		public int get_sysfs_attr_as_int (string name);
		[CCode (array_length = false)]
		public unowned string?[] get_sysfs_attr_as_strv (string name);
		public uint64 get_sysfs_attr_as_uint64 (string name);
		public unowned string get_sysfs_path ();
		public bool has_property (string key);
		[NoWrapper]
		public virtual void reserved1 ();
		[NoWrapper]
		public virtual void reserved2 ();
		[NoWrapper]
		public virtual void reserved3 ();
		[NoWrapper]
		public virtual void reserved4 ();
		[NoWrapper]
		public virtual void reserved5 ();
		[NoWrapper]
		public virtual void reserved6 ();
		[NoWrapper]
		public virtual void reserved7 ();
		[NoWrapper]
		public virtual void reserved8 ();
	}
	[CCode (cheader_filename = "gudev/gudev.h")]
	[SimpleType]
	[IntegerType (rank = 9)]
	public struct DeviceNumber : Posix.dev_t {
	}
	[CCode (cprefix = "G_UDEV_DEVICE_TYPE_", cheader_filename = "gudev/gudev.h")]
	public enum DeviceType {
		NONE,
		BLOCK,
		CHAR
	}
}
