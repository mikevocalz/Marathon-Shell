.pragma library

// Keep the BB10-style two-column overview on phones. More columns appear
// only when each cover has room for its live content and action banner.
function columns(availableWidth, scaleFactor) {
    const scale = Math.max(0.75, scaleFactor || 1);
    const preferredCoverWidth = 296 * scale;
    return Math.max(2, Math.min(4, Math.floor(Math.max(0, availableWidth) / preferredCoverWidth)));
}

function itemsPerPage(columnCount, rowsPerPage) {
    return Math.max(1, columnCount * rowsPerPage);
}

function pageCount(taskCount, columnCount, rowsPerPage) {
    return Math.max(1, Math.ceil(Math.max(0, taskCount) / itemsPerPage(columnCount, rowsPerPage)));
}

function pageForIndex(index, columnCount, rowsPerPage) {
    return Math.floor(Math.max(0, index) / itemsPerPage(columnCount, rowsPerPage));
}

function clampPage(page, taskCount, columnCount, rowsPerPage) {
    return Math.max(0, Math.min(page, pageCount(taskCount, columnCount, rowsPerPage) - 1));
}
