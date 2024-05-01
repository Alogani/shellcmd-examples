##[
    version       = "0.1.0"
    author        = "alogani"
    description   = "Helpers to create and launch a virtual machine using qemu"
    license       = "MIT"

    requires "shellcmd = 0.2.0"
]##

import shellcmd, shellcmd/[qemu, ui]
import std/parseopt

const
    Home = "/home/alogani"
    VmPath = Home/"work/debian.img"
    IsoPath = Home/"iso/debian-12.5.0-amd64-netinst.iso"
    ImageSize = 2.GB
    MntFolder = "/mnt"

const
    CpuCount = 2
    RamSize = 1536.MB

proc createImg() {.async.} =
    implicitAwait(@["sh"]):
        if not sh.exists(VmPath) or sh.askYesNo("Erase current VM"):
            sh.unlink(VmPath)
            sh.createDisk(VMPath, ImageSize, Raw)
            sh.startVm(VMPath, Raw, runOptions = { WithBootMenu }, cdromDisk = IsoPath, cpuCount = CpuCount, ram = RamSize)

proc run(): Future[void] =
    sh.startVM(VMPath, Raw, cpuCount = CpuCount, ram = RamSize)

proc syncFolder(srcLocal, destVm: Path) {.async.} =
    ## Vm must be shut down
    implicitAwait(@["sh"]):
        let loopDisk = sh.attachLoopDev(VmPath)
        defer: sh.detachLoopDev(loopDisk[0])
        sh.mount(loopDisk[1], MntFolder)
        defer: sh.umount(MntFolder)
        sh.mkdir(MntFolder/destVm, true)
        sh.rsync(srcLocal, MntFolder/destVm)

proc main() {.async.} =
    var p = initOptParser()
    while true:
        p.next()
        case p.kind
        of cmdEnd: break
        of cmdLongOption:
            if p.key == "create":
                await createImg()
            elif p.key == "run":
                await run()
            elif p.key == "sync":
                p.next()
                if p.kind != cmdArgument: raise
                var src = p.val
                p.next()
                if p.kind != cmdArgument: raise
                var dest = p.val
                await syncFolder(src, dest)
        else:
            break

waitFor main()