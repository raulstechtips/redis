# Keep this Sentinel's identity and global epoch unchanged.
$1 == "sentinel" && ($2 == "myid" || $2 == "current-epoch") {
    print
    next
}

# This deployment monitors one group. Rename its group-scoped records without
# changing the selected primary, discovered peers, or election epochs.
$1 == "sentinel" && $2 ~ /^(monitor|known-replica|known-sentinel|config-epoch|leader-epoch)$/ {
    $3 = master
    if ($2 == "monitor") {
        $NF = quorum
    }
    print
}
