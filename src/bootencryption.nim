##[
  version       = "0.1.0"
  author        = "alogani"
  description   = "Semi automatic full disk encryption script based on https://cryptsetup-team.pages.debian.net/cryptsetup/encrypted-boot.html"
  license       = "MIT"

  requires "shellcmd = 0.1.0"
]##

## For debian
## Not fully tested yet

import std/strformat
import shellcmd
import shellcmd/[luks, ui]

let blockCryptName = "boot_crypt"

proc main() {.async.} =
    implicitAwait(@["sh"]):
        ## Encrypting boot and updating crypttab and fstab
        let hasEFI = sh.isMountPoint "/boot/efi"
        if hasEfi: sh.umount "/boot/efi"
        var bootDev = sh.findMntSource "/boot"
        var bootDevOldUuid = sh.getBlockDevInfo(bootdev, Uuid)
        sh.mount "/boot", { Remount, ReadOnly }
        sh.tarCreate "/boot", "/tmp/boot.tar"
        sh.umount "/boot"
        # Erase it
        sh.wipeDisk bootDev
        sh.luksEncrypt bootDev, luks1 = true
        var bootDevNewUuid = sh.getBlockDevInfo(bootdev, Uuid)
        sh.writeFile("/etc/crypttab", &"{blockCryptName} UUID={bootDevNewUuid} none luks", append = true)
        sh.daemonReload()
        sh.restart "cryptsetup.target"
        sh.mke2fs("/dev/mapper" / blockCryptName, Ext2, uuid = bootDevOldUuid) # To avoid modifying fstab
        sh.mount "/boot"
        sh.tarExtract "/tmp/boot.tar", "/boot"
        if hasEfi: sh.mount "/boot/efi"

        ## Enabling cryptomount inside grub2
        sh.writeFile("/etc/default/grub", "GRUB_ENABLE_CRYPTODISK=y", append = true)
        sh.runAssertDiscard(@["update-grub"])
        sh.runAssertDiscard(@["grub-install", bootDev])
        echo "Here is actual luks iteration count: "
        echo sh.runGetOutput(@[&"cryptsetup luksDump {bootDev} | grep -B1 'Iterations:'"], ProcArgsModifier(toRemove: {QuoteArgs}))
        var num = (sh).askString("Please choose an iteration count")
        sh.runAssertDiscard(@["cryptsetup", "luksChangeKey", "--pbkdf-force-iterations", num, bootDev])

waitFor main()