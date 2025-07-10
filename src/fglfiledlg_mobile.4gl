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

TYPE t_file_entry RECORD
       fname STRING,
       descr STRING
     END RECORD

FUNCTION browse()
  DEFINE retstr STRING
  OPEN WINDOW file_browser WITH FORM "fglfiledlg_mobile" ATTRIBUTE(TYPE=POPUP, STYLE="popup")
  CALL list_dir(os.Path.pwd(),os.Path.pwd()) RETURNING retstr
     --CALL list_dir(".",".") RETURNING retstr
  CLOSE WINDOW file_browser
END FUNCTION

FUNCTION list_dir(pwd,prev)
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
END FUNCTION

PRIVATE FUNCTION ext_is_text(ext)
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
