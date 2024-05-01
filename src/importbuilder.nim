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

proc createImportBuilder(srcDir: Path, dest: Path = "", exports = true) {.async.} =
    ## If dest is empty, the dest will be in the same directory
    ## eg: createImportBuilder(mylib/exports) -> mylib/exports.nim
    ## Set exports = false if you just want to build docs
    var
        folderPath: string
        dest = dest
    if $dest == "":
        folderPath = "./" & srcDir.extractFilename()
        dest = srcDir.addFileExt("nim")
    else:
        if srcDir.isAbsolute():
            folderPath = srcDir
        else:
            folderPath = srcDir.relativePath(dest.parentDir())

    implicitAwait(@["sh"]):
        var allNimFiles = sh.find(srcDir, @[excludeDirContent(matchName("private")) or matchName("*.nim")], ditchRootName = true)
        allNimFiles = seq[string](allNimFiles).naturalSort()
        if sh.exists(dest) and not sh.askYesNo("Overwrite " & dest):
            return
        let f = open(dest, fmWrite)
        for fileToImport in allNimFiles:
            f.writeLine("import " & string(folderPath / fileToImport.changeFileExt("")))
            if exports:
                f.writeLine("export " & fileToImport.splitFile().name)
        f.close()

proc main() {.async.} =
    var p = initOptParser()
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
                let dest = if p.kind == cmdArgument:
                        p.key
                    else:
                        ""
                p.next()
                let discardExports = p.key == "discardExports"
                await createImportBuilder(srcDir, dest, not discardExports)
                p.next()
        else:
            break

waitFor main()