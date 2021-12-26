/*
 *  Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)
 *  NOTE: This is an adaptation of the DndHandler class from elementary Files project.
 *  Copyright (c) 2017-2019 José Amuedo (https://github.com/spheras)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Authors: Jeremy Wootten <jeremy@elementaryos.org>
 */

namespace DesktopFolder.DragnDrop {

    public class DndHandler : GLib.Object {
        Gdk.DragAction chosen = Gdk.DragAction.DEFAULT;

        /** singlenton instance */
        private static DndHandler dnd_handler = null;

        /**
         * @constructor
         * @description private constructor for singlenton
         */
        private DndHandler () {
        }

        /**
         * @name get_instance
         * @description singlenton pattern
         */
        public static DndHandler get_instance () {
            if (dnd_handler == null) {
                dnd_handler = new DndHandler ();
            }
            return dnd_handler;
        }

        public bool dnd_perform (Gtk.Widget widget,
            DndView                         drop_target,
            GLib.List <GLib.File>           drop_file_list,
            Gdk.DragAction                  action) {
            // debug("DndHandler-dnd_perform!!!");
            /*
               debug("size:%d",(int)drop_file_list.length());
               debug("file:"+drop_file_list.nth(0).data.get_basename());
             */

            if (drop_target.is_folder ()) {
                DesktopFolder.DragnDrop.Util.copy_move (drop_file_list,
                    drop_target.get_target_location (),
                    action,
                    widget,
                    null,
                    null);
                return true;
            }
            return false;
        }

        public Gdk.DragAction ? drag_drop_action_ask (Gtk.Widget dest_widget,
            Gtk.ApplicationWindow win,
            Gdk.DragAction possible_actions) {
            // debug("DndHandler-drag_drop_action_ask!!!");
            this.chosen = Gdk.DragAction.DEFAULT;
            add_action (win);
            var ask_menu = build_menu (possible_actions);
            ask_menu.set_screen (dest_widget.get_screen ());
            ask_menu.show_all ();
            var loop = new GLib.MainLoop (null, false);

            ask_menu.deactivate.connect (() => {
                if (loop.is_running ())
                    loop.quit ();

                remove_action (win);
            });

            ask_menu.popup_at_pointer (null);
            loop.run ();
            Gtk.grab_remove (ask_menu);

            return this.chosen;
        }

        private void add_action (Gtk.ApplicationWindow win) {
            // debug("DndHandler-add_action!!!");
            var action = new GLib.SimpleAction ("choice", GLib.VariantType.STRING);
            action.activate.connect (this.on_choice);

            win.add_action (action);
        }

        private void remove_action (Gtk.ApplicationWindow win) {
            // debug("DndHandler-remove_action!!!");
            win.remove_action ("choice");
        }

        private Gtk.Menu build_menu (Gdk.DragAction possible_actions) {
            // debug("DndHandler-build_menu!!!");
            var menu = new Gtk.Menu ();

            build_and_append_menu_item (menu, DesktopFolder.Lang.DROP_MENU_MOVE, Gdk.DragAction.MOVE, possible_actions);
            build_and_append_menu_item (menu, DesktopFolder.Lang.DROP_MENU_COPY, Gdk.DragAction.COPY, possible_actions);
            build_and_append_menu_item (menu, DesktopFolder.Lang.DROP_MENU_LINK, Gdk.DragAction.LINK, possible_actions);

            menu.append (new Gtk.SeparatorMenuItem ());
            menu.append (new Gtk.MenuItem.with_label (DesktopFolder.Lang.DROP_MENU_CANCEL));

            return menu;
        }

        private void build_and_append_menu_item (Gtk.Menu menu, string label, Gdk.DragAction ? action, Gdk.DragAction possible_actions) {
            // debug("DndHandler-build_and_append_menu_item!!!");
            if ((possible_actions & action) != 0) {
                var item = new Gtk.MenuItem.with_label (label);

                item.activate.connect (() => {
                    this.chosen = action;
                });

                menu.append (item);
            }
        }

        public void on_choice (GLib.Variant ? param) {
            // debug("DndHandler-on_choice!!!");
            if (param == null || !param.is_of_type (GLib.VariantType.STRING)) {
                critical ("Invalid variant type in DndHandler Menu");
                return;
            }

            string choice = param.get_string ();

            switch (choice) {
            case "move":
                this.chosen = Gdk.DragAction.MOVE;
                break;
            case "copy":
                this.chosen = Gdk.DragAction.COPY;
                break;
            case "link":
                this.chosen = Gdk.DragAction.LINK;
                break;
            case "background": /* not implemented yet */
            case "cancel":
            default:
                this.chosen = Gdk.DragAction.DEFAULT;
                break;
            }
        }

        public string ? get_source_filename (Gdk.DragContext context) {
            // debug("DndHandler-get_source_filename!!!");
            uchar[] ? data = null;
            Gdk.Atom property_name = Gdk.Atom.intern_static_string ("XdndDirectSave0");
            Gdk.Atom property_type = Gdk.Atom.intern_static_string ("text/plain");

            bool exists            = Gdk.property_get (context.get_source_window (),
                    property_name,
                    property_type,
                    0, /* offset into property to start getting */
                    1024, /* max bytes of data to retrieve */
                    0, /* do not delete after retrieving */
                    null, null, /* actual property type and format got disregarded */
                    out data
                );

            if (exists && data != null) {
                string name = DndHandler.data_to_string (data);
                if (GLib.Path.DIR_SEPARATOR.to_string () in name) {
                    warning ("invalid source filename");
                    return null; /* not a valid filename */
                } else
                    return name;
            } else {
                warning ("source file does not exist");
                return null;
            }
        }

        public void set_source_uri (Gdk.DragContext context, string uri) {
            // debug("DndHandler-set_source_uri!!!");
            // debug ("DNDHANDLER: set source uri to %s", uri);
            Gdk.Atom property_name = Gdk.Atom.intern_static_string ("XdndDirectSave0");
            Gdk.Atom property_type = Gdk.Atom.intern_static_string ("text/plain");
            Gdk.property_change (context.get_source_window (),
                property_name,
                property_type,
                8,
                Gdk.PropMode.REPLACE,
                uri.data,
                uri.length);
        }

        public bool handle_xdnddirectsave (Gdk.DragContext context,
            DragnDrop.DndView                              drop_target,
            Gtk.SelectionData                              selection) {
            // debug("DndHandler-handle_xdnddirectsave!!!");
            bool success = false;

            if (selection.get_length () == 1 && selection.get_format () == 8) {
                uchar result = selection.get_data ()[0];

                switch (result) {
                case 'F':
                    /* No fallback for XdndDirectSave stage (3), result "F" ("Failed") yet */
                    break;
                case 'E':
                    /* No fallback for XdndDirectSave stage (3), result "E" ("Error") yet.
                     * Note this result may be obtained even if the file was successfully saved */
                    break;
                case 'S':
                    /* XdndDirectSave "Success" */
                    success = true;
                    break;
                default:
                    warning ("Unhandled XdndDirectSave result %s", result.to_string ());
                    break;
                }
            }

            if (!success)
                set_source_uri (context, "");

            return success;
        }

        public bool handle_netscape_url (Gdk.DragContext context, DragnDrop.DndView drop_target, Gtk.SelectionData selection) {
            // debug("DndHandler-handle_netscape_url!!!");
            string[] parts = (selection.get_text ()).split ("\n");

            /* _NETSCAPE_URL looks like this: "$URL\n$TITLE" - should be 2 parts */
            if (parts.length != 2)
                return false;

            /* NETSCAPE URLs are not currently handled.  No current bug reports */
            return false;
        }

        public bool handle_file_drag_actions (Gtk.Widget dest_widget,
            Gtk.ApplicationWindow                        win,
            Gdk.DragContext                              context,
            DragnDrop.DndView                            drop_target,
            GLib.List <GLib.File>                        drop_file_list,
            Gdk.DragAction                               possible_actions,
            Gdk.DragAction                               suggested_action,
            uint32                                       timestamp) {

            // debug("DndHandler-handle_file_drag_actions!!!");
            bool           success = false;
            Gdk.DragAction action  = suggested_action;

            if (drop_file_list != null) {
                if ((possible_actions & Gdk.DragAction.ASK) != 0) {
                    action = drag_drop_action_ask (dest_widget, win, possible_actions);
                }

                if (action != Gdk.DragAction.DEFAULT) {
                    success = dnd_perform (dest_widget,
                            drop_target,
                            drop_file_list,
                            action);
                }

            } else {
                critical ("Attempt to drop null file list");
            }

            return success;
        }

        public static bool selection_data_is_uri_list (Gtk.SelectionData selection_data, uint info, out string ? text) {
            text = null;

            // debug("DndHandler-selection_data_is_uri_list!!!");
            if (info == TargetType.TEXT_URI_LIST &&
                selection_data.get_format () == 8 &&
                selection_data.get_length () > 0) {

                text = DndHandler.data_to_string (selection_data.get_data_with_length ());
            }

            // debug ("DNDHANDLER selection data is uri list returning %s", (text != null).to_string ());
            return (text != null);
        }

        public static string data_to_string (uchar[] cdata) {
            // debug("DndHandler-data_to_string!!!");
            var sb = new StringBuilder ("");

            foreach (uchar u in cdata) {
                sb.append_c ((char) u);
            }

            return sb.str;
        }

        public static void set_selection_data_from_file_list (Gtk.SelectionData selection_data,
            GLib.List <DndView>                                                 file_list,
            string                                                              prefix = "") {

            // debug("DndHandler-set_selection_data_from_file_list!!!");
            GLib.StringBuilder sb = new GLib.StringBuilder (prefix);

            if (file_list != null && file_list.data != null && file_list.data is DragnDrop.DndView) {
                bool in_recent = file_list.data.is_recent_uri_scheme ();

                file_list.@foreach ((file) => {
                    var target = in_recent ? file.get_display_target_uri () : file.get_target_location ().get_uri ();
                    // debug("target->%s",target);
                    sb.append (target);
                    sb.append ("\r\n"); /* Drop onto Filezilla does not work without the "\r" */
                });
            } else {
                warning ("Invalid file list for drag and drop ignored");
            }

            selection_data.@set (selection_data.get_target (),
                8,
                sb.data);

        }

        public static void set_selection_data_from_file_list_2 (Gtk.SelectionData selection_data,
            GLib.List <DragnDrop.DndView>                                         file_list,
            string                                                                prefix = "") {

            // debug("DndHandler-set_selection_data_from_file_list!!!");
            GLib.StringBuilder sb = new GLib.StringBuilder (prefix);

            if (file_list != null && file_list.data != null && file_list.data is DragnDrop.DndView) {
                bool in_recent = true; // file_list.data.is_recent_uri_scheme ();

                file_list.@foreach ((file) => {
                    var target = in_recent ? Util.get_display_target_uri (file.get_file ()) : file.get_file ().get_uri ();
                    // debug("target->%s",target);
                    sb.append (target);
                    sb.append ("\r\n"); /* Drop onto Filezilla does not work without the "\r" */
                });
            } else {
                warning ("Invalid file list for drag and drop ignored");
            }

            selection_data.@set (selection_data.get_target (),
                8,
                sb.data);

        }

    }
}
