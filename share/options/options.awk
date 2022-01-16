BEGIN {
    SHORT=""
    LONG=""
}

($0 ~ /^--[a-z]+/) {
    gsub(/--/, "", $1);

    if ($2 == "boolean") {
        LONG=LONG $1 ","
    } else {
        LONG=LONG $1 ":,"
    }
}

($0 ~ /^-[a-z]+/) {
    split($1, OPTS, ",")
    gsub(/-/, "", OPTS[1])

    if ($2 == "boolean") {
        SHORT=SHORT OPTS[1]
    } else {
        SHORT=SHORT OPTS[1] ":"
    }

    gsub(/--/, "", OPTS[2]);

    if ($2 == "boolean") {
        LONG=LONG OPTS[2] ","
    } else {
        LONG=LONG OPTS[2] ":,"
    }
}

END {
    if (SHORT != "") {
        printf "-o " SHORT " --long " LONG
    } else {
        printf "--long " LONG
    }
}
