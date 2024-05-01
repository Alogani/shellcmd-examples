##[
    version       = "0.1.0"
    author        = "alogani"
    description   = "Permit to create a nim file that imports and rexports a whole directory tree"
    license       = "MIT"

    requires "shellcmd = 0.2.1"
    requires "aloganimisc = 0.1.1"
]##

import shellcmd, shellcmd/ui
import aloganimisc/naturalsortalgos
import std/parseopt

proc createImportBuilder(srcDir: Path, dest: Path = ""): Future[string] {.async.} =
    ## If dest is empty, the dest will be in the same directory
    ## eg: createImportBuilder(mylib/exports) -> mylib/exports.nim
    var
        folderName = srcDir.extractFilename()
        dest = dest
    if $dest == "":
        dest = srcDir.addFileExt("nim")

    implicitAwait(@["sh"]):
        var allNimFiles = sh.find(srcDir, @[matchName("*.nim") or excludeDirContent(matchName("private"))], ditchRootName = true)
        allNimFiles = seq[string](allNimFiles).naturalSort()
        if sh.exists(dest) and not sh.askYesNo("Overwrite " & dest):
            return
        let f = open(dest, fmWrite)
        for fileToImport in allNimFiles:
            f.writeLine("import ./" & string(folderName / fileToImport.changeFileExt("")))
            f.writeLine("export " & fileToImport.splitFile().name)
        f.close()
    return dest

proc main() {.async.} =
    var p = initOptParser()
    var dest: string
    p.next()
    while true:
        case p.kind
        of cmdEnd: break
        of cmdLongOption:
            if p.key == "build":
                p.next()
                if p.kind != cmdArgument: raise
                var srcDir = p.key
                p.next()
                if p.kind != cmdArgument:
                    dest = await createImportBuilder(srcDir)
                else:
                    dest = await createImportBuilder(srcDir, p.key)
        else:
            break

waitFor main()