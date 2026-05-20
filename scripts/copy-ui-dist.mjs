import { cpSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';

const srcDir = 'ui/dist';
const destDir = 'public';
const preserve = new Set(['robots.txt', 'cache-bust.txt']);

if (!existsSync(srcDir)) {
  console.error(`Missing ${srcDir}. Run the UI build first.`);
  process.exit(1);
}

mkdirSync(destDir, { recursive: true });

for (const entry of readdirSync(destDir)) {
  if (preserve.has(entry)) continue;
  rmSync(join(destDir, entry), { recursive: true, force: true });
}

cpSync(srcDir, destDir, { recursive: true });

console.log(`Copied ${srcDir} -> ${destDir}`);
