export class DiffLine {
  kind: string = 'meta'; text: string = ''; oldNumber: string = ''; newNumber: string = '';
}
export function diffLines(value: string): DiffLine[] {
  let oldLine: number = 0; let newLine: number = 0; let inHunk: boolean = false;
  return value.split('\n').map((text: string) => {
    const line: DiffLine = new DiffLine(); line.text = text;
    const hunk: RegExpMatchArray | null = text.match(/^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (hunk) { oldLine = Number(hunk[1]); newLine = Number(hunk[2]); inHunk = true; line.kind = 'hunk'; }
    else if (text.startsWith('修改记录 ')) { inHunk = false; }
    else if (inHunk && text.startsWith('+')) { line.kind = 'add'; line.newNumber = (newLine++).toString(); }
    else if (inHunk && text.startsWith('-')) { line.kind = 'remove'; line.oldNumber = (oldLine++).toString(); }
    else if (inHunk && text.startsWith(' ')) { line.kind = 'context'; line.oldNumber = (oldLine++).toString(); line.newNumber = (newLine++).toString(); }
    return line;
  });
}
