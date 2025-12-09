#!/bin/bash

shopt -s nullglob

# --- Helper Functions ---
msg_info() { echo " [i] $1"; }
msg_ok()   { echo " [✔] $1"; }
msg_warn() { echo " [!] $1"; }
msg_err()  { echo " [✘] $1"; }

pause() {
    echo
    read -rp " Press [Enter] to return to Main Menu..."
}

show_header() {
    clear
    now=$(date +"%Y-%m-%d %H:%M:%S")
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                 LINUX FILE MANAGEMENT SYSTEM                          ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo " "
    echo " Location : $(pwd)"
    echo " Time     : $now"
    echo "─────────────────────────────────────────────────────────────────────────"
}

resolve_target() {
    input="$1"
    if [ -e "$input" ]; then
        echo "$input"
        return
    fi
    # Use find to locate file if not in current dir
    found=$(find . -name "$input" -print -quit 2>/dev/null)
    if [ -n "$found" ]; then
        echo "$found"
    else
        echo ""
    fi
}

show_dir_lists() {
    echo "┌── Directories ───────────────────────┐"
    # FIX: Using arrays instead of ls parsing to avoid showing '.' as a folder
    dirs=(*/)
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "│  (none)"
    else
        # Show only first 10
        for d in "${dirs[@]:0:10}"; do
            echo "│  📂 ${d%/}"
        done
    fi

    echo "├── Files ─────────────────────────────┤"
    mapfile -t files < <(ls -p 2>/dev/null | grep -v / | head -n 10)
    if [ ${#files[@]} -eq 0 ]; then
        echo "│  (none)"
    else
        for f in "${files[@]}"; do
            echo "│  📄 $f"
        done
    fi
    echo "└──────────────────────────────────────┘"
}

navigate() {
    echo "--- Navigation Mode ---"
    echo " Current: $(pwd)"
    dirs=(*/)

    if [ ${#dirs[@]} -eq 0 ]; then
        echo " (No subdirectories found)"
    else
        echo " Available Folders:"
        i=1
        for d in "${dirs[@]}"; do
            echo "  [$i] 📂 ${d%/}"
            ((i++))
        done
    fi

    echo "───────────────────────────────────────"
    echo " Enter Number, Directory Name, or '..' to go back:"
    read -r newpath

    case "$newpath" in
        "") msg_err "No path provided." ;;
        "..") cd .. && msg_ok "Moved Back to $(pwd)" ;;
        *)
            if [[ "$newpath" =~ ^[0-9]+$ ]] && [ "$newpath" -ge 1 ] && [ "$newpath" -le "${#dirs[@]}" ]; then
                cd "${dirs[$((newpath-1))]}" && msg_ok "Entered: $(pwd)"
            elif [ -d "$newpath" ]; then
                cd "$newpath" && msg_ok "Entered: $(pwd)"
            elif [ -d "./$newpath" ]; then
                cd "./$newpath" && msg_ok "Entered: $(pwd)"
            else
                msg_err "Directory not found."
            fi
            ;;
    esac
}

list_files() {
    echo "--- List Files ---"
    echo "Enter path (Press Enter for current):"
    read -r dir
    target="${dir:-.}"

    if [ ! -d "$target" ]; then
        msg_err "Directory not found."
        return
    fi

    echo "┌── Contents of: $target ─────────────┐"

    mapfile -t ldirs < <(ls -d "$target"/*/ 2>/dev/null | head -n 20)
    echo "├── Directories ───────────────────────┤"
    if [ ${#ldirs[@]} -eq 0 ]; then
        echo "│  (none)"
    else
        for d in "${ldirs[@]}"; do
            name=$(basename "$d")
            echo "│  📂 $name"
        done
    fi

    mapfile -t lfiles < <(ls -p "$target" 2>/dev/null | grep -v / | head -n 20)
    echo "├── Files ─────────────────────────────┤"
    if [ ${#lfiles[@]} -eq 0 ]; then
        echo "│  (none)"
    else
        for f in "${lfiles[@]}"; do
            echo "│  📄 $f"
        done
    fi

    echo "└──────────────────────────────────────┘"
}

create_file() {
    echo "--- Create File ---"
    echo " [1] 📘 C Source      (.c)"
    echo " [2] 🐚 Shell Script  (.sh)"
    echo " [3] 📝 Text File     (.txt)"
    echo -n " Choose type (1-3): "
   
    read -r type
    echo "Filename (no extension):"
    read -r name

    [ -z "$name" ] && { msg_err "Name required."; return; }

    case "$type" in
        1) ext=".c" ;;
        2) ext=".sh" ;;
        3) ext=".txt" ;;
        *) msg_err "Invalid type."; return ;;
    esac

    echo "Save Path (Enter for current):"
    read -r savepath

    full="$name$ext"

    if [ -z "$savepath" ]; then
        touch "$full"
    elif [ -d "$savepath" ]; then
        touch "$savepath/$full"
    else
        msg_err "Path not found."
        return
    fi

    case "$ext" in
        ".c")   msg_ok "Created C source file: $full" ;;
        ".sh")  msg_ok "Created Shell script: $full" ;;
        ".txt") msg_ok "Created Text file: $full" ;;
    esac
}

delete_file() {
    echo "--- Delete (File/Directory) ---"
    show_dir_lists
    echo "Enter filename or path:"
    read -r target

    [ -z "$target" ] && { msg_err "Name required."; return; }

    real_target=$(resolve_target "$target")
    [ -z "$real_target" ] && { msg_err "Not found."; return; }

    if [ -f "$real_target" ]; then
        echo "Target: $real_target"
        read -rp "Delete file? (y/n): " c
        if [[ "$c" =~ ^[yY]$ ]]; then
            rm "$real_target"
            msg_ok "File deleted."
        else
            msg_warn "File deletion cancelled."
        fi
    elif [ -d "$real_target" ]; then
        echo "Target: $real_target"
        read -rp "Delete directory recursively? (y/n): " c
        if [[ "$c" =~ ^[yY]$ ]]; then
            rm -r "$real_target"
            msg_ok "Directory deleted."
        else
            msg_warn "Directory deletion cancelled."
        fi
    else
        msg_err "Target invalid."
    fi
}

rename_file() {
    echo "--- Rename / Move ---"
    show_dir_lists
    echo "Current name or path:"
    read -r old

    [ -z "$old" ] && { msg_err "Name required."; return; }

    real_old=$(resolve_target "$old")
    [ -z "$real_old" ] && { msg_err "Target not found."; return; }

    echo "New name or path:"
    read -r new
    [ -z "$new" ] && { msg_err "New name required."; return; }

    if [[ "$new" == "/" ]]; then
        final="$new"
    else
        final="$(dirname "$real_old")/$new"
    fi

    mv "$real_old" "$final"
    msg_ok "Renamed to: $final"
}

edit_file() {
    echo "--- Edit File ---"
    show_dir_lists
    echo "File to edit (name or path):"
    read -r file

    [ -z "$file" ] && { msg_err "Filename required."; return; }

    real_file=$(resolve_target "$file")
    [ -z "$real_file" ] && { msg_err "File not found."; return; }

    if [ -f "$real_file" ]; then
        nano "$real_file"
    else
        msg_err "Target is not a regular file."
    fi
}

search_file() {
    echo "--- Search File ---"
    echo "1) Current Dir   2) Full System"
    read -r mode
    echo "Filename:"
    read -r name

    [ -z "$name" ] && { msg_err "Filename required."; return; }

    msg_info "Searching..."
    echo "┌── Search Results ─────────────────────┐"

    found_any=0
    idx=1

    if [ "$mode" = "2" ]; then
        while IFS= read -r path; do
            echo "│  $idx) $path"
            found_any=1
            idx=$((idx+1))
        done < <(find / -name "$name" 2>/dev/null)
    else
        base=$(pwd)
        while IFS= read -r path; do
            echo "│  $idx) $path"
            found_any=1
            idx=$((idx+1))
        done < <(find "$base" -name "$name" 2>/dev/null)
    fi

    if [ "$found_any" -eq 0 ]; then
        echo "│  (no matches)"
    fi

    echo "└──────────────────────────────────────┘"
    msg_ok "Search completed."
}

view_content() {
    echo "--- View Content ---"
    echo "Filename or path:"
    read -r file

    [ -z "$file" ] && { msg_err "Filename required."; return; }

    real_file=$(resolve_target "$file")
    [ -z "$real_file" ] && { msg_err "File not found."; return; }

    if [ -f "$real_file" ]; then
        if file "$real_file" | grep -q "text"; then
            echo "--- Start: $real_file ---"
            cat "$real_file"
            echo ""
            echo "--- End ---"
        else
            msg_warn "Binary/Image file detected. Cannot view."
        fi
    elif [ -d "$real_file" ]; then
        msg_err "Cannot view directory as text."
    else
        msg_err "Target invalid."
    fi
}

copy_file() {
    echo "--- Copy File ---"
    show_dir_lists
    echo "Source file (name or path):"
    read -r src

    [ -z "$src" ] && { msg_err "Source required."; return; }

    real_src=$(resolve_target "$src")
    [ -z "$real_src" ] && { msg_err "Source file not found."; return; }
    [ ! -f "$real_src" ] && { msg_err "Source is not a regular file."; return; }

    echo "Destination (path or full path with new name):"
    read -r dest
    [ -z "$dest" ] && { msg_err "Destination required."; return; }

    dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ] && [ ! -d "$dest" ]; then
        msg_err "Destination directory does not exist."
        return
    fi

    if cp -i "$real_src" "$dest"; then
        msg_ok "Copied successfully."
    else
        msg_err "Copy failed."
    fi
}

main_loop() {
    while true; do
        show_header
        echo " 1. Navigate         6. Edit File"
        echo " 2. List Files       7. Search File"
        echo " 3. Create File      8. View Content"
        echo " 4. Delete File/Dir  9. Copy File"
        echo " 5. Rename/Move      0. Exit"
        echo "─────────────────────────────────────────────────────────────────────────"
        echo -n " Enter Choice: "
        read -r choice

        case "$choice" in
            1) navigate ;;
            2) list_files ;;
            3) create_file ;;
            4) delete_file ;;
            5) rename_file ;;
            6) edit_file ;;
            7) search_file ;;
            8) view_content ;;
            9) copy_file ;;
            0) msg_ok "Exiting... Goodbye!"; break ;;
            *) msg_err "Invalid choice!" ;;
        esac

        [ "$choice" != "0" ] && pause
    done
}

main_loop