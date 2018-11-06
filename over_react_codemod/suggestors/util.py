import codemod

from over_react_codemod import util


def suggest_patches(pattern, lines, updater, insert_at_end=False):
    for start, end, new_lines in util.find_patches(pattern, lines, updater):
        if insert_at_end:
            start = len(lines)
            end = start
        yield codemod.Patch(
            start_line_number=start,
            end_line_number=end,
            new_lines=new_lines,
        )

