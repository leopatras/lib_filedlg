# Property of Four Js*
# (c) Copyright Four Js 1995, 2025. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
# 
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

#+ File open/save dialog box using MD
IMPORT FGL fgldialog
IMPORT os

PUBLIC TYPE FILEDLG_RECORD RECORD
    title STRING,
    defaultfilename STRING,
    defaultpath STRING,
    opt_create_dirs SMALLINT,  -- allows the creation of a new subdirectory 
                               --(not yet implemented)
    opt_delete_files SMALLINT, -- allows to delete files when running the dialog
    types DYNAMIC ARRAY OF RECORD -- list for the file type combobox
      description STRING, -- string to display
      suffixes STRING -- pipe separated string of all possible suffixes for one entry
                      -- example "*.per|*.4gl"
    END RECORD
END RECORD

DEFINE _filedlg_list DYNAMIC ARRAY OF RECORD
                    eimage STRING, -- image name
                    entry STRING, -- Filename or Dirname
                    esize INT,    --file size
                    emodt STRING, --modification time
                    etype STRING -- C_DIRECTORY or "*.xxx File"
                END RECORD

DEFINE last_opendlg_directory STRING
DEFINE last_savedlg_directory STRING
DEFINE m_typearr DYNAMIC ARRAY OF STRING
DEFINE m_typelen INT
CONSTANT C_DIRECTORY="Directory"
CONSTANT C_OPEN="open"
CONSTANT C_SAVE="save"

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
  LET t= "Open File"
  IF r.title IS NOT NULL THEN
    LET t = r.title
  END IF
  LET fn = _filedlg_doDlg(C_OPEN,t,r.*)
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
  LET fn = _filedlg_doDlg(C_SAVE,t,r.*)
  IF fn IS NOT NULL THEN
    LET last_savedlg_directory = _file_get_dirname(fn)
  END IF
  RETURN fn
END FUNCTION

------------------- internal _filedlg_xxx functions ----------------------------

FUNCTION _filedlg_doDlg(dlgtype,title,r)
  DEFINE dlgtype STRING
  DEFINE title STRING
  DEFINE r FILEDLG_RECORD
  DEFINE currpath, path, filename, ftype, dirname, filepath STRING
  DEFINE delfilename, errstr STRING
  DEFINE doContinue, i INT
  DEFINE cb ui.ComboBox

  OPEN WINDOW _filedlg WITH FORM "filedlg"
       ATTRIBUTES(STYLE='dialog',TEXT=title)

  CALL fgl_settitle(title)

  LET currpath = r.defaultpath
  LET filename = r.defaultfilename
  DISPLAY BY NAME filename

  IF currpath="." THEN 
    LET currpath=os.Path.pwd()
  END IF
  DISPLAY currpath TO currpath
  LET cb = ui.ComboBox.forName("formonly.ftype")
  IF cb IS NULL THEN
     DISPLAY "ERROR:form field \"ftype\" not found in form filedlg"
     EXIT PROGRAM
  END IF
  FOR i=1 TO r.types.getLength()
    CALL cb.addItem(r.types[i].suffixes,r.types[i].description)
  END FOR
  LET ftype=r.types[1].suffixes
  DIALOG ATTRIBUTE(UNBUFFERED)
    --use a DISPLAY ARRAY for showing the file list
    DISPLAY ARRAY _filedlg_list TO sr.* 
      BEFORE DISPLAY
        --the following call is not effective, but should be!!!
        CALL DIALOG.setActionActive("del",r.opt_delete_files)

      BEFORE ROW 
        IF _filedlg_list[arr_curr()].etype<>C_DIRECTORY THEN
          LET filename=_filedlg_list[arr_curr()].entry
          DISPLAY BY NAME filename 
        END IF

      ON ACTION del --ask for deleting the highlighted file
        LET delfilename=_filedlg_list[arr_curr()].entry
        IF _filedlg_mbox_yn("Confirm delete",sfmt("Really delete '%1'?",delfilename),"question") THEN
          CALL _file_delete(os.Path.join(currpath,delfilename))
          CALL _filedlg_fetch_filenames(DIALOG,currpath,ftype,NULL)
        END IF

    END DISPLAY

    INPUT BY NAME filename,ftype ATTRIBUTE(WITHOUT DEFAULTS)
      --when the type combobox changes we need to redisplay
      ON CHANGE ftype
        CALL _filedlg_fetch_filenames(DIALOG,currpath,ftype,NULL)

    END INPUT

    BEFORE DIALOG
      CALL _filedlg_fetch_filenames(DIALOG,currpath,ftype,filename)
      IF dlgtype = C_SAVE THEN
        NEXT FIELD filename
      END IF

    ON ACTION accept
      LET doContinue=FALSE
      --we use DIALOG.getCurrentItem() to detect where the focus currently is
      --it works similar like INFIELD however also for DISPLAY ARRAY
      IF DIALOG.getCurrentItem()="sr" THEN
        --we are in the display array
        LET filepath = os.Path.join(currpath,_filedlg_list[arr_curr()].entry)
      ELSE
        --not in display array
        LET filepath = os.Path.join(currpath,filename)
      END IF
      IF os.Path.exists(filepath) AND os.Path.isDirectory(filepath) THEN
        --switch  the directory and refill the array
        LET currpath=_file_normalize_dir(filepath)
        CALL _filedlg_fetch_filenames(DIALOG,filepath,ftype,"..")
        DISPLAY BY NAME currpath
        LET filename=""
        LET doContinue=TRUE
      END IF
      IF NOT doContinue AND dlgtype = C_OPEN THEN
        IF NOT os.Path.exists(filepath) THEN
          LET errstr=SFMT(%"file '%1' does not exist!",
                          os.Path.baseName(filepath))
          CALL _filedlg_mbox_ok("Error", errstr, "stop")
          ERROR errstr
          LET doContinue=TRUE
        END IF
      END IF
      IF NOT doContinue AND dlgtype = C_SAVE THEN
        LET dirname=_file_get_dirname(filepath) 
        IF NOT os.Path.exists(dirname) THEN
          CALL _filedlg_mbox_ok("Error", SFMT(%"directory '%1' does not exist!",filepath), "stop")
          LET doContinue=TRUE
        END IF
      END IF
      IF NOT doContinue THEN
        EXIT DIALOG
      END IF

    ON ACTION cancel
      LET filepath=NULL
      EXIT DIALOG

    ON ACTION move_up --move 1 directory level up
      LET path = _file_get_dirname(currpath)
      CALL _filedlg_fetch_filenames(DIALOG,path,ftype,currpath)
      LET currpath=path
      DISPLAY BY NAME currpath


  END DIALOG
  CLOSE WINDOW _filedlg
  RETURN filepath
END FUNCTION

FUNCTION _filedlg_fetch_filenames(d,currpath,typelist,currfile)
  DEFINE d ui.Dialog
  DEFINE currpath STRING
  DEFINE typelist STRING
  DEFINE currfile STRING
  DEFINE i,len,found INT
  DEFINE st base.StringTokenizer
  LET st = base.StringTokenizer.create(typelist,"|")
  CALL m_typearr.clear()
  WHILE st.hasMoreTokens()
    LET m_typearr[m_typearr.getLength()+1]=st.nextToken()
  END WHILE
  LET m_typelen=m_typearr.getLength()
  CALL _filedlg_getfiles_int(currpath) 
  LET len=_filedlg_list.getLength()
  --jump to the current file
  LET currfile=os.Path.baseName(currfile)
  FOR i=1 TO len
    IF currfile=_filedlg_list[i].entry THEN
      LET found=1
      CALL d.setCurrentRow("sr",i)
      EXIT FOR
    END IF
  END FOR
  IF NOT found THEN
     CALL d.setCurrentRow("sr",1)
  END IF
END FUNCTION

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
      LET pname = os.Path.join(dirpath,fname)
      LET isdir=os.Path.isDirectory(pname)
      IF isdir THEN
         LET size = NULL
      ELSE
         LET size = os.Path.size(pname)
      END IF
      CALL _filedlg_appendEntry(isdir,fname,size,os.Path.mtime(pname))
  END WHILE
  CALL os.Path.dirClose(dh)
END FUNCTION

FUNCTION _filedlg_in_typearr(type)
  DEFINE type STRING
  DEFINE i INT
  FOR i=1 TO m_typelen
    IF type=m_typearr[i] THEN
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

FUNCTION _filedlg_checktypeandext(ext)
  DEFINE ext STRING
  IF _filedlg_in_typearr("*") THEN
     RETURN TRUE
  END IF
  IF ext IS NOT NULL THEN
     IF _filedlg_in_typearr("*.*") THEN
        RETURN TRUE
     END IF
     IF _filedlg_in_typearr("*"||ext) THEN
        RETURN TRUE
     END IF
  END IF
  RETURN FALSE
END FUNCTION

FUNCTION _filedlg_appendEntry(isdir,name,size,modDate)
  DEFINE isdir INT
  DEFINE name STRING
  DEFINE size INT
  DEFINE modDate STRING
  DEFINE type,image,ext STRING
  DEFINE len INT
  IF isdir THEN
    LET ext=""
    LET type=C_DIRECTORY
    LET image="folder"
  ELSE
    LET ext = _file_extension(name)
    LET type = SFMT(%"%1-File",ext)
    LET image="file"
  END IF
  IF NOT isdir AND NOT _filedlg_checktypeandext(ext) THEN
    RETURN
  END IF
  CALL _filedlg_list.appendElement()
  LET len=_filedlg_list.getLength()
  LET _filedlg_list[len].entry  = name
  LET _filedlg_list[len].etype  = type
  LET _filedlg_list[len].eimage = image
  LET _filedlg_list[len].esize  = size
  LET _filedlg_list[len].emodt  = modDate
END FUNCTION

FUNCTION _filedlg_mbox_ok(title,message,icon)
  DEFINE title, message, icon STRING
  CALL fgl_winMessage(title,message,icon)
END FUNCTION

FUNCTION _filedlg_mbox_yn(title,message,icon)
  DEFINE title, message, icon STRING
  DEFINE r STRING
  LET r = fgl_winQuestion(title,message,"yes","yes|no",icon,0)
  RETURN ( r == "yes" )
END FUNCTION

-------------------------- _file helpers ---------------------------------------

FUNCTION _file_get_dirname(filename)
  DEFINE filename STRING
  DEFINE dirname STRING
  LET dirname=os.Path.dirName(filename)
  IF dirname IS NULL THEN
    LET dirname="."
  END IF
  RETURN dirname
END FUNCTION

FUNCTION _file_extension(filename)
  DEFINE filename STRING
  DEFINE extension STRING
  LET extension=os.Path.extension(filename)
  IF extension IS NOT NULL THEN
    LET extension=".",extension
  END IF
  RETURN extension
END FUNCTION

FUNCTION _file_delete(filename)
  DEFINE filename STRING
  IF NOT os.Path.delete(filename) THEN
    CALL _filedlg_mbox_ok("Error",sfmt("Can't delete %1",filename),"stop")
  END IF
END FUNCTION

--normalizes a given directory name
--example /home/foo/bar/../spong -> /home/foo/spong
FUNCTION _file_normalize_dir(fname)
  DEFINE fname STRING
  RETURN os.Path.fullPath(fname)
END FUNCTION
