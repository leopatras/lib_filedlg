# Property of Four Js*
# (c) Copyright Four Js 1995, 2025. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
#
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.
 
# Property of Four Js*
# (c) Copyright Four Js 1995, 2025. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
#
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.
 
OPTIONS SHORT CIRCUIT
IMPORT os
IMPORT FGL fgldialog
 
--mobile struct
TYPE t_file_entry RECORD
       fname STRING,
       descr STRING
     END RECORD
 
 
 
--migrated dlg struct
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
 
################################################ list from filedlg
 
DEFINE _filedlg_list DYNAMIC ARRAY OF RECORD
                    eimage STRING, -- image name
                    entry STRING, -- file/dir name
                    esize INT,    -- size
                    emodt STRING, --mod time
                    etype STRING -- C_DIRECTORY or "*.xxx File"
                END RECORD
------------------constants----------------------------------      
DEFINE last_opendlg_directory STRING
DEFINE last_savedlg_directory STRING
DEFINE m_typearr DYNAMIC ARRAY OF STRING
DEFINE m_typelen INT
CONSTANT C_DIRECTORY="Directory"
CONSTANT C_OPEN="open"
CONSTANT C_SAVE="save"
#######################################################################
--TREE:
DEFINE tree_arr DYNAMIC ARRAY OF RECORD
    name STRING,       --name of dir or file
    image STRING,      --image
    parentid STRING,   --name of parent dir
    id STRING,         --name of current dir
    expanded BOOLEAN,  --expanded or not (current dir)
    isdir BOOLEAN      --is this node a dir?
END RECORD
#################################################################################
###############################################################################
--tree view functions
FUNCTION fill_tree()
    CALL tree_arr.clear()
    CALL recursive_fill_tree(".", NULL)  -- "." = current directory, NULL = root
END FUNCTION
##################################################################
FUNCTION recursive_fill_tree(path, parent_id)
    DEFINE path, parent_id STRING --path: curr folder that's scanned, par_id: id of parent node
    DEFINE dh INT --direcotry handle
    DEFINE fname, fullpath STRING --current file name being read + path to this file
    DEFINE isdir BOOLEAN
    DEFINE i INT --index to insert into tree_arr
 
    --tries to open a dir, if failed, exit.
    LET dh = os.Path.dirOpen(path)
    IF dh == 0 THEN
        RETURN
    END IF
    --start loop: loop through each item in the dir
    WHILE TRUE
        LET fname = os.Path.dirNext(dh) --gets file name
        IF fname IS NULL THEN EXIT WHILE END IF --exit if file name == NULL
        IF fname == "." OR fname == ".." THEN CONTINUE WHILE END IF --ignore current dir and parent dirs
 
        LET fullpath = os.Path.join(path, fname) --create full path to current file/dir
       
        LET i = tree_arr.getLength() + 1
        --increment and appeds file/dir info into tree array
        LET tree_arr[i].name = fname
        LET tree_arr[i].image = IIF(isdir, "folder.png", "file.png")
        LET tree_arr[i].parentid = parent_id
        LET tree_arr[i].id = fullpath
        LET tree_arr[i].expanded = FALSE
        LET tree_arr[i].isdir = os.Path.isDirectory(fullpath)
 
        --if is dir and has children, make recursive call to further decipher this dir
        IF isdir THEN
            CALL recursive_fill_tree(fullpath, fullpath)
        END IF
    END WHILE
 
   CALL os.Path.dirClose(dh)
 
END FUNCTION
 
----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
 
FUNCTION browse() ------------------keep
  DEFINE retstr STRING
  OPEN WINDOW file_browser WITH FORM "fglfiledlg_mobile" ATTRIBUTE(TYPE=POPUP, STYLE="popup")
  CALL list_dir(os.Path.pwd(),os.Path.pwd()) RETURNING retstr
     --CALL list_dir(".",".") RETURNING retstr
  CLOSE WINDOW file_browser
END FUNCTION
 
 
#Dodlg function:
FUNCTION _filedlg_doDlg(dlgtype,title,r)
  DEFINE dlgtype STRING
  DEFINE title STRING
  DEFINE r FILEDLG_RECORD
  DEFINE currpath, path, filename, ftype, dirname, filepath STRING
  DEFINE delfilename, errstr STRING
  DEFINE doContinue, i INT
  DEFINE cb ui.ComboBox
 
  OPEN WINDOW _filedlg WITH FORM "fglfiledlg"
       ATTRIBUTE(STYLE='dialog',TEXT=title)
 
  CALL fgl_settitle(title)
  #######################FILL TREE#################
  CALL fill_tree()
  #################################################
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
 
 
    -- show tree view
    DISPLAY ARRAY tree_arr TO tr.*
        BEFORE ROW
            DISPLAY "Selected node: ", tree_arr[DIALOG.getCurrentRow("tr")].name
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
 
    ON ACTION move_up
      LET path = _file_get_dirname(currpath)
      CALL _filedlg_fetch_filenames(DIALOG,path,ftype,currpath)
      LET currpath=path
      DISPLAY BY NAME currpath
      --new add below:
      CALL select_tree_node_by_path(currpath)
      --clean tree
      CALL tree_arr.clear()
      --RESET TREE:
      CALL recursive_fill_tree(currpath, NULL)
      --CALLING tree go up
      CALL go_up_one_level(DIALOG)
 
 
  END DIALOG
  CLOSE WINDOW _filedlg
  RETURN filepath
END FUNCTION
 
 
 
--Selects a node and expands it
FUNCTION select_tree_node_by_path(path)
  DEFINE path STRING
  DEFINE i INT
  FOR i = 1 TO tree_arr.getLength()
    LET tree_arr[i].expanded = (tree_arr[i].id == path)
    IF tree_arr[i].expanded THEN
      CALL ui.Dialog.getCurrent().setCurrentRow("tr", i)
    END IF
  END FOR
  # --loops through tree array
  # FOR i = 1 TO tree_arr.getLength()
  # --if id -- input path then expands it
  # IF tree_arr[i].id == path THEN
  #     LET tree_arr[i].expanded = TRUE
  #       CALL ui.Dialog.getCurrent().setCurrentRow("tr", i)
  #       # ELSE
  #       # LET tree_arr[i].expanded = false
  # EXIT FOR
  # END IF
  # END FOR
END FUNCTION
 
--helps the tree view back out of current directory
FUNCTION go_up_one_level(dlg)
   
     DEFINE dlg ui.Dialog
     DEFINE curr_row INT
     DEFINE parent_id STRING
     DEFINE i INT
 
     -- get the current row in tree view
     LET curr_row = dlg.getCurrentRow("tr")
     --exit if no valid selection
     IF curr_row IS NULL OR curr_row <= 0 THEN
         RETURN  
    END IF
 
     -- get the parent id of the selected node
     LET parent_id = tree_arr[curr_row].parentid
     --if no parent --> at root already
     IF parent_id IS NULL THEN
         RETURN  
     END IF
 
    -- find the index of the parent node in the tree array
     FOR i = 1 TO tree_arr.getLength()
         IF tree_arr[i].id == parent_id THEN
          --if parent found, expand parent
             LET tree_arr[i].expanded = true
             CALL dlg.setCurrentRow("tr", i)
             EXIT FOR
         END IF
     END FOR
 
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
 
 
 
FUNCTION list_dir(pwd,prev)---------------keep
   DEFINE pwd,prev,curr,pLast,entry,ext,fname,retstr,formName,dirname STRING
   DEFINE parr DYNAMIC ARRAY OF t_file_entry
   DEFINE i,ok INT
   IF NOT fill_dir(pwd,parr,FALSE) THEN
     RETURN "back"
   END IF
   LET dirname=os.Path.baseName(os.Path.fullPath(pwd))
   CALL fgl_settitle(dirname)
   DISPLAY ARRAY parr TO parr.* ATTRIBUTES(UNBUFFERED,CANCEL=FALSE)
     BEFORE DISPLAY
       CALL DIALOG.setActionHidden("view",1)
       CALL DIALOG.setActionHidden("delall",1)
       IF dirname=="gic_logs" AND parr.getLength()>1 THEN
         CALL DIALOG.setActionHidden("delall",0)
       END IF
       LET pLast=os.Path.baseName(os.Path.fullPath(prev))
       FOR i=1 TO parr.getLength()
         LET entry=parr[i].fname
         IF entry.getIndexOf(pLast,1)==1 OR
           (entry=="../" AND os.Path.fullPath(os.Path.join(pwd,entry))==os.Path.fullPath(prev)) THEN
           CALL fgl_set_arr_curr(i) --mark the location we came from
           EXIT FOR
         END IF
       END FOR
     ON ACTION close
       EXIT DISPLAY
     ON ACTION exit
       RETURN "exit"
     ON DELETE
      LET int_flag=TRUE
      IF fgl_winQuestion("Delete",SFMT("Really delete '%1'?",parr[arr_curr()].fname),"yes","yes|no","info",1)=="yes" THEN
        CALL os.Path.delete(os.Path.join(pwd,parr[arr_curr()].fname)) RETURNING ok
        IF ok THEN
          LET int_flag=FALSE
        ELSE
          ERROR SFMT("can't delete '%1'",parr[arr_curr()].fname)
        END IF
      END IF
     ON ACTION delall
      IF fgl_winQuestion("Delete","Really delete all files in this directory?","yes","yes|no","info",1)=="yes" THEN
        CALL fill_dir(pwd,parr,TRUE) RETURNING retstr
      END IF
     BEFORE ROW
       LET ext=os.Path.extension(parr[arr_curr()].fname)
{
       DISPLAY SFMT("ext:%1,dir:%2,isDir:%3,isText:%4",ext,
            os.Path.JOIN(pwd,parr[arr_curr()].fname),
            os.Path.isDirectory(os.Path.JOIN(pwd,parr[arr_curr()].fname)),
            ext_is_text(ext))
}
       IF (NOT os.Path.isDirectory(os.Path.join(pwd,parr[arr_curr()].fname))) AND
          (ext_is_text(ext) OR ext_is_img(ext)) THEN
         CALL DIALOG.setActionHidden("view",0)
       END IF
     AFTER ROW
       CALL DIALOG.setActionHidden("view",1)
     ON ACTION showpath
       CALL fgl_winMessage("Current path is:",os.Path.fullPath(pwd),"info")
     ON ACTION view
       LET formName=IIF(ext_is_text(os.Path.extension(parr[arr_curr()].fname)),
                        "text_view" , "image_view" )
       OPEN WINDOW myview WITH FORM formName ATTRIBUTE(TYPE=POPUP, STYLE="popup",TEXT=parr[arr_curr()].fname)  
       LET fname=os.Path.join(pwd,parr[arr_curr()].fname)
       IF formName=="text_view" THEN
         DISPLAY string_from_file(fname) TO te
       ELSE
         DISPLAY fname TO img
       END IF
       MENU "View"
         ON ACTION cancel
           EXIT MENU
         COMMAND "Mail"
          CALL ui.Interface.frontCall("mobile","composeMail",["","GIC demo mail","","","",fname],[retstr])
          IF retstr<>"ok" OR retstr<>"cancel" THEN
            CALL fgl_winMessage("Result:",retstr,"info")
          END IF
       END MENU
       CLOSE WINDOW myview
     ON ACTION mkdir
       OPEN WINDOW mkdir WITH FORM "mkdir"
       LET int_flag=FALSE
       INPUT BY NAME dirname
       IF NOT int_flag AND dirname IS NOT NULL THEN
         CALL mkdir(os.Path.join(os.Path.fullPath(pwd),dirname))
       END IF
       CALL fill_dir(pwd,parr,FALSE) RETURNING retstr
       CLOSE WINDOW mkdir
     ON ACTION accept
       LET curr=parr[arr_curr()].fname
       IF os.Path.fullPath(os.Path.join(pwd,curr))==os.Path.fullPath(prev)
       THEN
         EXIT DISPLAY
       ELSE
         IF os.Path.isDirectory(os.Path.join(pwd,curr)) THEN
           --we recursively drill down
           IF list_dir(os.Path.join(pwd,curr),pwd)=="exit" THEN
             RETURN "exit" --go up the stack and leave all dialogs
           END IF
         END IF
       END IF
   END DISPLAY
   CALL fgl_settitle(os.Path.baseName(os.Path.fullPath(prev)))
   RETURN "back"
END FUNCTION ---------------------------------------------------------------thisone that is the end of listdir
 
 
PRIVATE FUNCTION ext_is_text(ext) -----------keep
  DEFINE ext STRING
  LET ext=ext.toLowerCase()
  IF ext=="log" OR ext=="txt" OR ext=="4gl" OR ext="per" OR ext="42f"  OR ext=="42s"
     OR ext="4ad" OR ext="4st" OR ext="js" OR ext="plist" OR ext="string" OR length(ext)=0
     THEN RETURN TRUE
  END IF
  RETURN FALSE
END FUNCTION
 
PRIVATE FUNCTION ext_is_img(ext)
  DEFINE ext STRING
  LET ext=ext.toLowerCase()
  IF ext=="png" OR ext="jpg" THEN
    RETURN TRUE
  END IF
  RETURN FALSE
END FUNCTION
 
PRIVATE FUNCTION fill_dir(dname,parr,deleteall)
   DEFINE dname STRING
   DEFINE parr DYNAMIC ARRAY OF t_file_entry
   DEFINE deleteall BOOLEAN
   DEFINE dh,idx INT
   --DEFINE mtime DATETIME YEAR TO SECOND
   DEFINE mtimeStr STRING
   DEFINE sizeStr STRING
   DEFINE isDir BOOLEAN
   DEFINE fname,nextFile,complete STRING
   CALL parr.clear()
   LET dh = os.Path.dirOpen(dname)
   IF dh == 0 THEN
     RETURN FALSE
   END IF
   LET idx=1
   LET nextFile=os.Path.dirNext(dh)
   WHILE (fname:=nextFile) IS NOT NULL
     LET nextFile=os.Path.dirNext(dh)
     IF fname=="." THEN
       CONTINUE WHILE
     END IF
     LET complete=os.Path.join(dname,fname)
     LET isDir=os.Path.isDirectory(complete)
     IF isDir THEN
       LET fname=fname,"/"
     ELSE
       IF deleteall AND os.Path.delete(complete) THEN
         CONTINUE WHILE
       END IF
     END IF
     LET parr[idx].fname = fname
     --LET mtimeStr = --os.Path.mtime(complete)
     LET mtimeStr = os.Path.rwx(complete)
     LET mtimeStr = IIF(mtimeStr IS NULL,"(NULL)",mtimeStr)
     LET sizeStr=IIF(isDir,"<DIR>",SFMT("%1 Bytes",os.Path.size(complete)))
     LET parr[idx].descr= SFMT("%1   %2", mtimeStr,sizeStr)
     IF os.Path.size(complete)==-1 THEN
       CALL fgl_winMessage("Error", complete, "info")
     END IF
     LET idx=idx+1
   END WHILE
   CALL os.Path.dirClose(dh)
   IF NOT deleteall THEN
      CALL parr.sort("fname",FALSE)
   END IF
   RETURN TRUE
END FUNCTION
 
 
PRIVATE FUNCTION mkdir(dirname)
  DEFINE dirname STRING
  DEFINE ret INT
  DEFINE errmess STRING
  TRY
    CALL os.Path.mkdir(dirname) RETURNING ret
    IF NOT ret THEN
      LET errmess="Could not create 'en', ret:0"
    END IF
  CATCH
    LET errmess=SFMT("Could not create 'en', reason:%1",err_get(status))
  END TRY
  IF errmess IS NOT NULL THEN
    CALL fgl_winMessage("Error",errmess,"error")
  END IF
END FUNCTION
 
 
FUNCTION string_from_file(fname)
  DEFINE fname STRING
  DEFINE t TEXT
  DEFINE s STRING
  LOCATE t IN FILE fname
  LET s=t
  RETURN s
END FUNCTION