export function set_dialog_visibility(id, is_visible) {
    const dialog = document.getElementById(id)

    if (is_visible) {
        dialog.showModal()
    } else {
        dialog.close()
    }
}
