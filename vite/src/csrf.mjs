export function get_csrf_token() {
    let token = document.querySelector("meta[name='csrf-header-value']").getAttribute("content");

    if (token === null) {
        return "";
    }
    else {
        return token;
    }
}