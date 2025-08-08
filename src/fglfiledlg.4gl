# Property of Four Js*
# (c) Copyright Four Js 1995, 2025. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
#
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

OPTIONS
SHORT CIRCUIT
IMPORT os
IMPORT FGL fgldialog

--mobile struct
TYPE t_file_entry RECORD
  fname STRING,
  descr STRING
END RECORD

DEFINE currpath, path, filename, ftype, dirname, filepath STRING

--migrated dlg struct
PUBLIC TYPE FILEDLG_RECORD RECORD
  title STRING,
  defaultfilename STRING,
  defaultpath STRING,
  opt_create_dirs SMALLINT, -- allows the creation of a new subdirectory
  --(not yet implemented)
  opt_delete_files SMALLINT, -- allows to delete files when running the dialog
  types DYNAMIC ARRAY OF RECORD -- list for the file type combobox
    description STRING, -- string to display
    suffixes
        STRING -- pipe separated string of all possible suffixes for one entry
  -- example "*.per|*.4gl"
  END RECORD
END RECORD

################################################ list from filedlg

DEFINE _filedlg_list DYNAMIC ARRAY OF RECORD
  eimage STRING, -- image name
  entry STRING, -- file/dir name
  esize INT, -- size
  emodt STRING, --mod time
  etype STRING -- C_DIRECTORY or "*.xxx File"
END RECORD
------------------constants----------------------------------
DEFINE last_opendlg_directory STRING
DEFINE last_savedlg_directory STRING
DEFINE m_typearr DYNAMIC ARRAY OF STRING
DEFINE m_typelen INT
CONSTANT C_DIRECTORY = "Directory"
CONSTANT C_OPEN = "open"
CONSTANT C_SAVE = "save"
#######################################################################
--TREE:
DEFINE tree_arr DYNAMIC ARRAY OF RECORD
  name STRING, --name of dir or file
  image STRING, --image
  parentid STRING, --name of parent dir
  id STRING, --name of current dir
  expanded BOOLEAN, --expanded or not (current dir)
  isdir BOOLEAN, --is this node a dir?
  hasChildren BOOLEAN --DOES THIS DIR HAVE CHILREN?
END RECORD

#+ Clears and initializes the tree view with the current working directory.
#+ @returnType void
#+ @return None.
#
FUNCTION fill_tree()
  CALL tree_arr.clear()
  --expand root dir
  CALL expand_dirs(0)
END FUNCTION

#+ Expands the directory node at index p and inserts its child directories.
#+ @returnType void
#+ @return None.
#+ @param p The index in the tree array to expand.
#
PRIVATE FUNCTION expand_dirs(p)
  DEFINE p INT --index of node in the tree array to expand
  DEFINE parent_path STRING --parent path
  DEFINE dh INT --directory handle
  DEFINE fname, fullpath STRING
  DEFINE isdir BOOLEAN --isdir or not
  DEFINE i INT

  --if at root level (= 0), there is no parent path
  IF p == 0 THEN
    LET parent_path = ""
  ELSE
    LET parent_path =
        tree_arr[p].id --the dir being expanded becomes the parent, id
    LET tree_arr[p].expanded = TRUE --mark as expaded
  END IF

  -- Determine which directory to scan
  LET dh = os.Path.dirOpen(IIF(p == 0, ".", parent_path))
  IF dh == 0 THEN
    RETURN
  END IF

  --loop through the contents in a directory
  LET i = p --start at index of the expanded dir and increment
  WHILE TRUE
    LET fname = os.Path.dirNext(dh) --get next item in directory
    IF fname IS NULL THEN
      EXIT WHILE
    END IF
    IF fname == "."
        OR fname == ".." THEN --skip any current dir or parent dir stuff
      CONTINUE WHILE
    END IF

    LET fullpath =
        os.Path.join(IIF(p == 0, ".", parent_path), fname) --construct full path
    LET isdir = os.Path.isDirectory(fullpath) --check if entry is a dir or not
    -- if not a directory then keep going!
    IF NOT isdir THEN
      CONTINUE WHILE
    END IF

    LET i =
        i
            + 1 --move to next idx and then insert the subdir into tree, while assigning all of its fields
    CALL tree_arr.insertElement(i)
    LET tree_arr[i].name = fname
    LET tree_arr[i].parentid = IIF(p == 0, "", parent_path)
    LET tree_arr[i].id = fullpath
    LET tree_arr[i].expanded = FALSE
    LET tree_arr[i].isdir = TRUE
    LET tree_arr[i].hasChildren = hasChildDirs(fullpath)
    LET tree_arr[i].image = "folder"
  END WHILE
  CALL os.Path.dirClose(dh) --done, close direcotry handle
END FUNCTION

#+ Recursively collapses the directory node at position `p` and removes its children.
#+ @returnType void
#+ @return None.
#+ @param p The index in the tree array to collapse.

PRIVATE FUNCTION collapse_dirs(p)
  DEFINE p INT --index of node that is expanded currently
  DEFINE parent_path STRING --path to node at p
  LET parent_path = tree_arr[p].id --get full path

  #########################loop######################
  #check: when reaching something that is not a child of this dir, collapsed all, exit., base case of recursion
  WHILE p < tree_arr.getLength()
    IF tree_arr[p + 1].parentid IS NULL
        OR tree_arr[p + 1].parentid != parent_path THEN
      EXIT WHILE
    END IF

    --recursive call
    CALL collapse_dirs(p + 1)
    CALL tree_arr.deleteElement(p + 1) --delte from array when collapsed
  END WHILE

  LET tree_arr[p].expanded = FALSE --mark fir as collapsed
END FUNCTION

#+ Checks if a given directory has any subdirectories.
#+ @returnType Boolean
#+ @return TRUE if at least one subdirectory exists; FALSE otherwise.
#+ @param dirpath The path to check for child directories.
PRIVATE FUNCTION hasChildDirs(dirpath)
  DEFINE dirpath STRING
  DEFINE dh INT
  DEFINE fname, fullpath STRING
  DEFINE isdir BOOLEAN
  LET dh = os.Path.dirOpen(dirpath) --see if you can open a dir properly.
  IF dh == 0 THEN
    RETURN FALSE
  END IF

  WHILE TRUE
    LET fname = os.Path.dirNext(dh) --fetch entries inside the dir
    IF fname IS NULL THEN --skip nulls
      EXIT WHILE
    END IF

    IF fname == "." OR fname == ".." THEN --skip any curr level or parent stuff
      CONTINUE WHILE
    END IF

    LET fullpath = os.Path.join(dirpath, fname)
    LET isdir = os.Path.isDirectory(fullpath)
    IF isdir THEN
      CALL os.Path.dirClose(dh)
      RETURN TRUE
    END IF
  END WHILE
  CALL os.Path.dirClose(dh) --close dh when done
  RETURN FALSE
END FUNCTION

#+ Opens a simple file browser window.
#+ @returnType String
#+ @return The result from the directory listing dialog, or NULL if canceled.
#
PUBLIC FUNCTION browse() ------------------keep
  DEFINE retstr STRING
  OPEN WINDOW file_browser
      WITH
      FORM "fglfiledlg_mobile"
      ATTRIBUTE(TYPE = POPUP, STYLE = "popup")
  CALL list_dir(os.Path.pwd(), os.Path.pwd()) RETURNING retstr
  --CALL list_dir(".",".") RETURNING retstr
  CLOSE WINDOW file_browser
END FUNCTION

#+ Displays and manages the file dialog screen.
#+ @returnType String
#+ @return The selected file path, or NULL if canceled.
#+ @param dlgtype The dialog mode (e.g., open or save).
#+ @param title The dialog window title.
#+ @param r The record containing file dialog configuration options.
#
FUNCTION _filedlg_doDlg(dlgtype, title, r)
  DEFINE dlgtype STRING
  DEFINE title STRING
  DEFINE r FILEDLG_RECORD
  -- DEFINE currpath, path, filename, ftype, dirname, filepath STRING
  DEFINE delfilename, errstr STRING
  DEFINE doContinue, i INT
  DEFINE cb ui.ComboBox
  DEFINE curr_row INT

  OPEN WINDOW _filedlg
      WITH
      FORM "fglfiledlg"
      ATTRIBUTE(STYLE = 'dialog', TEXT = title)

  VAR f = ui.Window.getCurrent().getForm()

  CALL f.setElementText("accept", IIF(dlgtype == C_OPEN, "Open", "Save"))

  CALL fgl_settitle(title)
  CALL fill_tree()
  LET currpath = r.defaultpath
  LET filename = r.defaultfilename
  DISPLAY BY NAME filename

  IF currpath = "." THEN
    LET currpath = os.Path.pwd()
  END IF
  DISPLAY currpath TO currpath
  LET cb = ui.ComboBox.forName("formonly.ftype")
  IF cb IS NULL THEN
    DISPLAY "ERROR:form field \"ftype\" not found in form filedlg"
    EXIT PROGRAM
  END IF
  FOR i = 1 TO r.types.getLength()
    CALL cb.addItem(r.types[i].suffixes, r.types[i].description)
  END FOR
  LET ftype = r.types[1].suffixes
  DIALOG ATTRIBUTE(UNBUFFERED)
    --use a DISPLAY ARRAY for showing the file list
    DISPLAY ARRAY _filedlg_list TO sr.*
      BEFORE DISPLAY
        --the following call is not effective, but should be!!!
        CALL DIALOG.setActionActive("del", r.opt_delete_files)

      BEFORE ROW
        IF _filedlg_list[arr_curr()].etype <> C_DIRECTORY THEN
          LET filename = _filedlg_list[arr_curr()].entry
          DISPLAY BY NAME filename
        END IF

      ON ACTION del --ask for deleting the highlighted file
        LET delfilename = _filedlg_list[arr_curr()].entry
        IF _filedlg_mbox_yn(
            "Confirm delete",
            SFMT("Really delete '%1'?", delfilename),
            "question") THEN
          CALL _file_delete(os.Path.join(currpath, delfilename))
          CALL _filedlg_fetch_filenames(DIALOG, currpath, ftype, NULL)
        END IF
    END DISPLAY

    DISPLAY ARRAY tree_arr TO tr.*
      ON EXPAND(i)
        CALL expand_dirs(i)
      ON COLLAPSE(i)
        CALL collapse_dirs(i)
      BEFORE ROW
        LET curr_row = DIALOG.getCurrentRow("tr")
        IF curr_row > 0 AND curr_row <= tree_arr.getLength() THEN
          DISPLAY "Selected node: ", tree_arr[curr_row].name
          -- Call this function below to sync with fihronize the list when tree nodes are clicked,
          -- this updates the list view with what is in the new directory selected in the tree
          CALL sync_list_with_tree(DIALOG, curr_row)
        END IF
    END DISPLAY

    INPUT BY NAME filename, ftype ATTRIBUTE(WITHOUT DEFAULTS)
      --when the type combobox changes we need to redisplay
      ON CHANGE ftype
        CALL _filedlg_fetch_filenames(DIALOG, currpath, ftype, NULL)
    END INPUT

    BEFORE DIALOG
      CALL _filedlg_fetch_filenames(DIALOG, currpath, ftype, filename)
      IF dlgtype = C_SAVE THEN
        NEXT FIELD filename
      END IF

    ON ACTION accept
      LET doContinue = FALSE
      --we use DIALOG.getCurrentItem() to detect where the focus currently is
      --it works similar like INFIELD however also for DISPLAY ARRAY
      IF DIALOG.getCurrentItem() = "sr" THEN
        --we are in the display array
        LET filepath = os.Path.join(currpath, _filedlg_list[arr_curr()].entry)
      ELSE
        --not in display array
        LET filepath = os.Path.join(currpath, filename)
      END IF
      IF os.Path.exists(filepath) AND os.Path.isDirectory(filepath) THEN
        --switch  the directory and refill the array
        LET currpath = _file_normalize_dir(filepath)
        CALL _filedlg_fetch_filenames(DIALOG, filepath, ftype, "..")
        DISPLAY BY NAME currpath
        LET filename = ""
        CALL highlight_treenode(currpath)
        LET doContinue = TRUE
      END IF
      IF NOT doContinue AND dlgtype = C_OPEN THEN
        IF NOT os.Path.exists(filepath) THEN
          LET errstr =
              SFMT(%"file '%1' does not exist!", os.Path.baseName(filepath))
          CALL _filedlg_mbox_ok("Error", errstr, "stop")
          ERROR errstr
          LET doContinue = TRUE
        END IF
      END IF
      IF NOT doContinue AND dlgtype = C_SAVE THEN
        LET dirname = _file_get_dirname(filepath)
        IF NOT os.Path.exists(dirname) THEN
          CALL _filedlg_mbox_ok(
              "Error",
              SFMT(%"directory '%1' does not exist!", filepath),
              "stop")
          LET doContinue = TRUE
        END IF
      END IF
      IF NOT doContinue THEN
        EXIT DIALOG
      END IF

    ON ACTION cancel
      LET filepath = NULL
      EXIT DIALOG

    ON ACTION move_up
      LET path = _file_get_dirname(currpath)
      CALL _filedlg_fetch_filenames(DIALOG, path, ftype, currpath)
      LET currpath = path
      DISPLAY BY NAME currpath
      CALL highlight_treenode(currpath)
      --call this function to refresh the tree view when directory changes
      CALL refresh_tree_for_path(currpath)

  END DIALOG
  CLOSE WINDOW _filedlg
  RETURN filepath
END FUNCTION

#+ Syncs the file list view to show contents of the selected tree node.
#+ @returnType void
#+ @return None.
#+ @param dlg The dialog handler.
#+ @param tree_idx The index of the selected tree node.
#
FUNCTION sync_list_with_tree(dlg, tree_idx)
  DEFINE dlg ui.Dialog
  DEFINE tree_idx INT
  DEFINE new_path STRING

  LET new_path =
      tree_arr[tree_idx]
          .id --get path of the node selected by going into the correct index in the tree array and getting its id
  LET currpath = new_path
  CALL _filedlg_fetch_filenames(
      dlg, new_path, ftype, NULL) --fills the list view with what is in the dir
  DISPLAY new_path TO currpath --displays the new path
END FUNCTION

#+ Highlights and expands the tree node corresponding to the given path.
#+ @returnType void
#+ @return None.
#+ @param path The full directory path to highlight in the tree.
#
FUNCTION highlight_treenode(path)
  DEFINE path STRING --dir path to find and highlight
  DEFINE i INT --loop control var
  DEFINE dlg ui.Dialog

  LET dlg = ui.Dialog.getCurrent()
  IF dlg IS NULL THEN
    RETURN
  END IF

  --loops to find the target to highlight
  FOR i = 1 TO tree_arr.getLength()
    IF tree_arr[i].id IS NOT NULL AND tree_arr[i].id == path THEN
      CALL dlg.setCurrentRow("tr", i)

      --if not expanded and has children, expand it
      IF NOT tree_arr[i].expanded AND tree_arr[i].hasChildren THEN
        CALL expand_dirs(i)
      END IF
      EXIT FOR
    END IF
  END FOR
END FUNCTION

#+ Refreshes the  tree view when entered into a new root directory.
#+ @returnType void
#+ @return None
#+ @param root_path The directory path to use as the root node.
#
FUNCTION refresh_tree_for_path(root_path)
  DEFINE root_path STRING
  CALL tree_arr.clear()

  CALL tree_arr.appendElement()
  LET tree_arr[1].name = os.Path.baseName(root_path)
  LET tree_arr[1].image = "folder"
  LET tree_arr[1].parentid = ""
  LET tree_arr[1].id = root_path
  LET tree_arr[1].expanded = TRUE
  LET tree_arr[1].isdir = TRUE
  LET tree_arr[1].hasChildren = hasChildDirs(root_path)
  CALL expand_dirs(1)
END FUNCTION

#+ This function prepares the file dialog by filtering files by type, populating the file list,
#+ and setting the selection to the current file if it exists, or to the first file otherwise.
#+ @returnType void
#+ @return None.
#+ @param d The dialog handler.
#+ @param currpath The current directory path.
#+ @param typelist Array of accepted file extensions.
#+ @param currfile The name of the file to highlight, if any.
#
FUNCTION _filedlg_fetch_filenames(d, currpath, typelist, currfile)
  DEFINE d ui.Dialog
  DEFINE currpath STRING
  DEFINE typelist STRING
  DEFINE currfile STRING
  DEFINE i, len, found INT
  DEFINE st base.StringTokenizer
  LET st = base.StringTokenizer.create(typelist, "|")
  CALL m_typearr.clear()
  WHILE st.hasMoreTokens()
    LET m_typearr[m_typearr.getLength() + 1] = st.nextToken()
  END WHILE
  LET m_typelen = m_typearr.getLength()
  CALL _filedlg_getfiles_int(currpath)
  LET len = _filedlg_list.getLength()
  --jump to the current file
  LET currfile = os.Path.baseName(currfile)
  FOR i = 1 TO len
    IF currfile = _filedlg_list[i].entry THEN
      LET found = 1
      CALL d.setCurrentRow("sr", i)
      EXIT FOR
    END IF
  END FOR
  IF NOT found THEN
    CALL d.setCurrentRow("sr", 1)
  END IF
END FUNCTION

#+ Scans a directory, gathers information about each file and subdirectory (name, type, size, modification time),
#+ and appends this information to a list for use in a file dialog or similar interface.
#+ @returnType void
#+ @return None.
#+ @param dirpath The directory to scan for files.
#
FUNCTION _filedlg_getfiles_int(dirpath)
  DEFINE dirpath STRING
  DEFINE dh, isdir INTEGER
  DEFINE fname, pname, size STRING
  CALL _filedlg_list.clear()
  LET dh = os.Path.dirOpen(dirpath)
  IF dh == 0 THEN
    RETURN
  END IF
  WHILE TRUE
    LET fname = os.Path.dirNext(dh)
    IF fname IS NULL THEN
      EXIT WHILE
    END IF
    IF fname == "." THEN
      CONTINUE WHILE
    END IF
    LET pname = os.Path.join(dirpath, fname)
    LET isdir = os.Path.isDirectory(pname)
    IF isdir THEN
      LET size = NULL
    ELSE
      LET size = os.Path.size(pname)
    END IF
    CALL _filedlg_appendEntry(isdir, fname, size, os.Path.mtime(pname))
  END WHILE
  CALL os.Path.dirClose(dh)
END FUNCTION

#+ checks whether a given string value (type) exists in the array m_typearr
#+ @returnType Boolean
#+ @return TRUE if the type is found; FALSE otherwise.
#+ @param type The file extension to check.
#
PRIVATE FUNCTION _filedlg_in_typearr(type)
  DEFINE type STRING
  DEFINE i INT
  FOR i = 1 TO m_typelen
    IF type = m_typearr[i] THEN
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

# This function is used to determine if a file extension matches the allowed file types
# for a file dialog, based on the patterns stored in m_typearr.
#+ @returnType Boolean
#+ @return TRUE if the extension is accepted; FALSE otherwise.
#+ @param ext The file extension to check.
#
PRIVATE FUNCTION _filedlg_checktypeandext(ext)
  DEFINE ext STRING
  IF _filedlg_in_typearr("*") THEN
    RETURN TRUE
  END IF
  IF ext IS NOT NULL THEN
    IF _filedlg_in_typearr("*.*") THEN
      RETURN TRUE
    END IF
    IF _filedlg_in_typearr("*" || ext) THEN
      RETURN TRUE
    END IF
  END IF
  RETURN FALSE
END FUNCTION

# This function adds a file or directory to the file dialog's list,
# setting its display properties and filtering out files that do not match the allowed types
#+ @returnType void
#+ @return None.
#+ @param isdir Boolean flag indicating if it's a directory.
#+ @param name Name of the file or directory.
#+ @param size Size of the file.
#+ @param modDate Last modification date of the file.
#
PRIVATE FUNCTION _filedlg_appendEntry(isdir, name, size, modDate)
  DEFINE isdir INT
  DEFINE name STRING
  DEFINE size INT
  DEFINE modDate STRING
  DEFINE type, image, ext STRING
  DEFINE len INT
  IF isdir THEN
    LET ext = ""
    LET type = C_DIRECTORY
    LET image = "folder"
  ELSE
    LET ext = _file_extension(name)
    LET type = SFMT(%"%1-File", ext)
    LET image = "file"
  END IF
  IF NOT isdir AND NOT _filedlg_checktypeandext(ext) THEN
    RETURN
  END IF
  CALL _filedlg_list.appendElement()
  LET len = _filedlg_list.getLength()
  LET _filedlg_list[len].entry = name
  LET _filedlg_list[len].etype = type
  LET _filedlg_list[len].eimage = image
  LET _filedlg_list[len].esize = size
  LET _filedlg_list[len].emodt = modDate
END FUNCTION

#+ Displays a message box with a title, text, and an icon
#+ @returnType void
#+ @return None.
#+ @param title The message box title.
#+ @param message The message content.
#+ @param icon The icon type (e.g., "info", "error").
#
PRIVATE FUNCTION _filedlg_mbox_ok(title, message, icon)
  DEFINE title, message, icon STRING
  CALL fgl_winMessage(title, message, icon)
END FUNCTION

#+ Displays an interactive message box with configurable buttons and returns the label of the button selected by the user
#+ @returnType Boolean
#+ @return TRUE if user selects Yes; FALSE if No.
#+ @param title The message box title.
#+ @param message The message content.
#+ @param icon The icon type (e.g., "question").
#
PRIVATE FUNCTION _filedlg_mbox_yn(title, message, icon)
  DEFINE title, message, icon STRING
  DEFINE r STRING
  LET r = fgl_winQuestion(title, message, "yes", "yes|no", icon, 0)
  RETURN (r == "yes")
END FUNCTION

-------------------------- _file helpers ---------------------------------------

#+ Extracts the directory portion from a file path.
#+ Returns current directory "." if no directory path is found.
#+ @returnType String
#+ @return The directory path, or "." if filename has no directory component.
#+ @param filename The full file path from which to extract the directory.
#
PRIVATE FUNCTION _file_get_dirname(filename)
  DEFINE filename STRING
  DEFINE dirname STRING
  LET dirname = os.Path.dirName(filename)
  IF dirname IS NULL THEN
    LET dirname = "."
  END IF
  RETURN dirname
END FUNCTION

#+ Extracts the file extension from a filename, including the leading dot.
#+ Returns NULL if the file has no extension.
#+ @returnType String
#+ @return The file extension with leading dot (e.g., ".txt"), or NULL if no extension.
#+ @param filename The filename from which to extract the extension.
#
PRIVATE FUNCTION _file_extension(filename)
  DEFINE filename STRING
  DEFINE extension STRING
  LET extension = os.Path.extension(filename)
  IF extension IS NOT NULL THEN
    LET extension = ".", extension
  END IF
  RETURN extension
END FUNCTION

#+ Deletes a file with user-friendly error reporting.
#+ Displays an error dialog if the deletion fails.
#+ @returnType void
#+ @return None.
#+ @param filename The full path to the file to delete.
#
PRIVATE FUNCTION _file_delete(filename)
  DEFINE filename STRING
  IF NOT os.Path.delete(filename) THEN
    CALL _filedlg_mbox_ok("Error", SFMT("Can't delete %1", filename), "stop")
  END IF
END FUNCTION

--normalizes a given directory name
--example /home/foo/bar/../spong -> /home/foo/spong
PRIVATE FUNCTION _file_normalize_dir(fname)
  DEFINE fname STRING
  RETURN os.Path.fullPath(fname)
END FUNCTION
##############################################################################################################################

#+ Opens a file dialog to open a file.
#+ @returnType String
#+ @return The selected file path, or NULL is canceled.
#+ @param r the record describing the file dialog
#
FUNCTION filedlg_open(r)
  DEFINE r FILEDLG_RECORD
  DEFINE t, fn STRING
  IF r.defaultpath IS NULL THEN
    IF last_opendlg_directory IS NULL THEN
      LET last_opendlg_directory = "."
    END IF
    LET r.defaultpath = last_opendlg_directory
  END IF
  LET t = "Open File"
  IF r.title IS NOT NULL THEN
    LET t = r.title
  END IF
  LET fn = _filedlg_doDlg(C_OPEN, t, r.*)
  IF fn IS NOT NULL THEN
    LET last_opendlg_directory = _file_get_dirname(fn)
  END IF
  RETURN fn
END FUNCTION

#+ Opens a file dialog to save a file.
#+ @returnType String
#+ @return The selected file path, or NULL is canceled.
#+ @param r The record describing the file dialog
#
FUNCTION filedlg_save(r)
  DEFINE r FILEDLG_RECORD
  DEFINE t, fn STRING
  IF r.defaultpath IS NULL THEN
    IF last_savedlg_directory IS NULL THEN
      LET last_savedlg_directory = "."
    END IF
    LET r.defaultpath = last_savedlg_directory
  END IF
  LET t = "Save File"
  IF r.title IS NOT NULL THEN
    LET t = r.title
  END IF
  LET fn = _filedlg_doDlg(C_SAVE, t, r.*)
  IF fn IS NOT NULL THEN
    LET last_savedlg_directory = _file_get_dirname(fn)
  END IF
  RETURN fn
END FUNCTION

#+ This function provides a full-featured, interactive file and directory browser,
#+ allowing users to navigate directories, view files, delete files, create directories,
#+ and perform other file management tasks within a dialog interface.
#+ @returnType String #+ @return "back" if user navigated back or operation completed normally, "exit" if user chose to exit completely.
#+ @param pwd The current working directory path to display.
#+ @param prev The previous directory path (used for navigation context and highlighting).
#
FUNCTION list_dir(pwd, prev) ---------------keep
  DEFINE pwd, prev, curr, pLast, entry, ext, fname, retstr, formName, dirname
      STRING
  DEFINE parr DYNAMIC ARRAY OF t_file_entry
  DEFINE i, ok INT
  IF NOT fill_dir(pwd, parr, FALSE) THEN
    RETURN "back"
  END IF
  LET dirname = os.Path.baseName(os.Path.fullPath(pwd))
  CALL fgl_settitle(dirname)
  DISPLAY ARRAY parr TO parr.* ATTRIBUTES(UNBUFFERED, CANCEL = FALSE)
    BEFORE DISPLAY
      CALL DIALOG.setActionHidden("view", 1)
      CALL DIALOG.setActionHidden("delall", 1)
      IF dirname == "gic_logs" AND parr.getLength() > 1 THEN
        CALL DIALOG.setActionHidden("delall", 0)
      END IF
      LET pLast = os.Path.baseName(os.Path.fullPath(prev))
      FOR i = 1 TO parr.getLength()
        LET entry = parr[i].fname
        IF entry.getIndexOf(pLast, 1) == 1
            OR (entry == "../"
                AND os.Path.fullPath(os.Path.join(pwd, entry))
                    == os.Path.fullPath(prev)) THEN
          CALL fgl_set_arr_curr(i) --mark the location we came from
          EXIT FOR
        END IF
      END FOR
    ON ACTION close
      EXIT DISPLAY
    ON ACTION exit
      RETURN "exit"
    ON DELETE
      LET int_flag = TRUE
      IF fgl_winQuestion(
              "Delete",
              SFMT("Really delete '%1'?", parr[arr_curr()].fname),
              "yes",
              "yes|no",
              "info",
              1)
          == "yes" THEN
        CALL os.Path.delete(os.Path.join(pwd, parr[arr_curr()].fname))
            RETURNING ok
        IF ok THEN
          LET int_flag = FALSE
        ELSE
          ERROR SFMT("can't delete '%1'", parr[arr_curr()].fname)
        END IF
      END IF
    ON ACTION delall
      IF fgl_winQuestion(
              "Delete",
              "Really delete all files in this directory?",
              "yes",
              "yes|no",
              "info",
              1)
          == "yes" THEN
        CALL fill_dir(pwd, parr, TRUE) RETURNING retstr
      END IF
    BEFORE ROW
      LET ext = os.Path.extension(parr[arr_curr()].fname)
{
       DISPLAY SFMT("ext:%1,dir:%2,isDir:%3,isText:%4",ext,
            os.Path.JOIN(pwd,parr[arr_curr()].fname),
            os.Path.isDirectory(os.Path.JOIN(pwd,parr[arr_curr()].fname)),
            ext_is_text(ext))
}
      IF (NOT os.Path.isDirectory(os.Path.join(pwd, parr[arr_curr()].fname)))
          AND (ext_is_text(ext) OR ext_is_img(ext)) THEN
        CALL DIALOG.setActionHidden("view", 0)
      END IF
    AFTER ROW
      CALL DIALOG.setActionHidden("view", 1)
    ON ACTION showpath
      CALL fgl_winMessage("Current path is:", os.Path.fullPath(pwd), "info")
    ON ACTION view
      LET formName =
          IIF(ext_is_text(os.Path.extension(parr[arr_curr()].fname)),
              "text_view",
              "image_view")
      OPEN WINDOW myview
          WITH
          FORM formName
          ATTRIBUTE(TYPE = POPUP,
              STYLE = "popup",
              TEXT = parr[arr_curr()].fname)
      LET fname = os.Path.join(pwd, parr[arr_curr()].fname)
      IF formName == "text_view" THEN
        DISPLAY string_from_file(fname) TO te
      ELSE
        DISPLAY fname TO img
      END IF
      MENU "View"
        ON ACTION cancel
          EXIT MENU
        COMMAND "Mail"
          CALL ui.Interface.frontCall(
              "mobile",
              "composeMail",
              ["", "GIC demo mail", "", "", "", fname],
              [retstr])
          IF retstr <> "ok" OR retstr <> "cancel" THEN
            CALL fgl_winMessage("Result:", retstr, "info")
          END IF
      END MENU
      CLOSE WINDOW myview
    ON ACTION mkdir
      OPEN WINDOW mkdir WITH FORM "mkdir"
      LET int_flag = FALSE
      INPUT BY NAME dirname
      IF NOT int_flag AND dirname IS NOT NULL THEN
        CALL mkdir(os.Path.join(os.Path.fullPath(pwd), dirname))
      END IF
      CALL fill_dir(pwd, parr, FALSE) RETURNING retstr
      CLOSE WINDOW mkdir
    ON ACTION accept
      LET curr = parr[arr_curr()].fname
      IF os.Path.fullPath(os.Path.join(pwd, curr))
          == os.Path.fullPath(prev) THEN
        EXIT DISPLAY
      ELSE
        IF os.Path.isDirectory(os.Path.join(pwd, curr)) THEN
          --we recursively drill down
          IF list_dir(os.Path.join(pwd, curr), pwd) == "exit" THEN
            RETURN "exit" --go up the stack and leave all dialogs
          END IF
        END IF
      END IF
  END DISPLAY
  CALL fgl_settitle(os.Path.baseName(os.Path.fullPath(prev)))
  RETURN "back"
END FUNCTION ---------------------------------------------------------------thisone that is the end of listdir

#+ Checks whether a given file extension corresponds to a recognized text file type
#+ Supports common text formats and Genero development file types.
#+ @returnType Boolean
#+ @return TRUE if the extension is a recognized text file type; FALSE otherwise.
#+ @param ext The file extension to check (with or without leading dot).
#
PRIVATE FUNCTION ext_is_text(ext) -----------keep
  DEFINE ext STRING
  LET ext = ext.toLowerCase()
  IF ext == "log"
      OR ext == "txt"
      OR ext == "4gl"
      OR ext = "per"
      OR ext = "42f"
      OR ext == "42s"
      OR ext = "4ad"
      OR ext = "4st"
      OR ext = "js"
      OR ext = "plist"
      OR ext = "string"
      OR length(ext) = 0 THEN
    RETURN TRUE
  END IF
  RETURN FALSE
END FUNCTION

#+ This function is used to determine if a file extension represents an image file type (specifically PNG or JPG),
#+ which can be useful for file dialogs or viewers that need to handle image files differently from other file types
#+ Currently supports common web image formats.
#+ @returnType Boolean
#+ @return TRUE if the extension is a recognized image file type; FALSE otherwise.
#+ @param ext The file extension to check (with or without leading dot).
#
PRIVATE FUNCTION ext_is_img(ext)
  DEFINE ext STRING
  LET ext = ext.toLowerCase()
  IF ext == "png" OR ext = "jpg" THEN
    RETURN TRUE
  END IF
  RETURN FALSE
END FUNCTION

#+ This function scans a directory, optionally deletes all files if requested,
#+ and fills an array with details about each entry (name, permissions, size, and description), handling errors as needed
#+ @returnType Boolean
#+ @return TRUE if directory was successfully read; FALSE if directory cannot be opened.
#+ @param dname The directory path to read.
#+ @param parr Dynamic array of t_file_entry to populate with directory contents.
#+ @param deleteall If TRUE, deletes all files (not directories) while populating the array.
#
PRIVATE FUNCTION fill_dir(dname, parr, deleteall)
  DEFINE dname STRING
  DEFINE parr DYNAMIC ARRAY OF t_file_entry
  DEFINE deleteall BOOLEAN
  DEFINE dh, idx INT
  --DEFINE mtime DATETIME YEAR TO SECOND
  DEFINE mtimeStr STRING
  DEFINE sizeStr STRING
  DEFINE isDir BOOLEAN
  DEFINE fname, nextFile, complete STRING
  CALL parr.clear()
  LET dh = os.Path.dirOpen(dname)
  IF dh == 0 THEN
    RETURN FALSE
  END IF
  LET idx = 1
  LET nextFile = os.Path.dirNext(dh)
  WHILE (fname := nextFile) IS NOT NULL
    LET nextFile = os.Path.dirNext(dh)
    IF fname == "." THEN
      CONTINUE WHILE
    END IF
    LET complete = os.Path.join(dname, fname)
    LET isDir = os.Path.isDirectory(complete)
    IF isDir THEN
      LET fname = fname, "/"
    ELSE
      IF deleteall AND os.Path.delete(complete) THEN
        CONTINUE WHILE
      END IF
    END IF
    LET parr[idx].fname = fname
    LET mtimeStr = os.Path.rwx(complete)
    LET mtimeStr = IIF(mtimeStr IS NULL, "(NULL)", mtimeStr)
    LET sizeStr = IIF(isDir, "<DIR>", SFMT("%1 Bytes", os.Path.size(complete)))
    LET parr[idx].descr = SFMT("%1   %2", mtimeStr, sizeStr)
    IF os.Path.size(complete) == -1 THEN
      CALL fgl_winMessage("Error", complete, "info")
    END IF
    LET idx = idx + 1
  END WHILE
  CALL os.Path.dirClose(dh)
  IF NOT deleteall THEN
    CALL parr.sort("fname", FALSE)
  END IF
  RETURN TRUE
END FUNCTION

#+ Used to create a new directory, and fgl_winMessage displays a message box to the user
#+ Displays error messages to user if directory creation fails.
#+ @returnType void
#+ @return None.
#+ @param dirname The full path of the directory to create.
#
PRIVATE FUNCTION mkdir(dirname)
  DEFINE dirname STRING
  DEFINE ret INT
  DEFINE errmess STRING
  TRY
    CALL os.Path.mkdir(dirname) RETURNING ret
    IF NOT ret THEN
      LET errmess = "Could not create 'en', ret:0"
    END IF
  CATCH
    LET errmess = SFMT("Could not create 'en', reason:%1", err_get(status))
  END TRY
  IF errmess IS NOT NULL THEN
    CALL fgl_winMessage("Error", errmess, "error")
  END IF
END FUNCTION

#+ This function loads the entire contents of a file into a string and returns it
#+ @returnType String
#+ @return The complete file contents as a string, or NULL if file cannot be read.
#+ @param fname The full path to the file to read.
#
FUNCTION string_from_file(fname)
  DEFINE fname STRING
  DEFINE t TEXT
  DEFINE s STRING
  LOCATE t IN FILE fname
  LET s = t
  RETURN s
END FUNCTION
