export function get_csrf_token() {
    let token = document.querySelector("meta[name='csrf-token']").getAttribute("content");

    if (token === null) {
        return "";
    }
    else {
        return token;
    }
}