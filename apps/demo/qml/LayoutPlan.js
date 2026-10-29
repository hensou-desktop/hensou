// Guessed fit thresholds, proved at +/- 1 in the layout contract tests.
var minimumInlineWidth = 220;
var minimumInlineHeight = 156;
var splitWidth = 600;
var shortHeight = 300;
function plan(width, height) {
    var inline = width >= minimumInlineWidth && height >= minimumInlineHeight;
    return {
        structure: !inline ? "overflow" : width >= splitWidth && height < shortHeight ? "split" : "stack",
        gap: Math.max(4, Math.min(12, Math.floor(Math.min(width, height) / 32))),
        inline: inline ? ["field", "checkbox", "list"] : [],
        overflow: inline ? [] : ["field", "checkbox", "list"]
    };
}
