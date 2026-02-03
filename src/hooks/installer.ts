/**
 * Hooks Installer - Dynamic settings.json generation
 * Installs hooks based on enabled integrations (similar to skills pattern)
 */

import { cpSync, mkdirSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

// Get bundled hooks directory (lettabot/hooks/)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const BUNDLED_HOOKS_DIR = resolve(__dirname, '../../hooks');

export interface HooksConfig {
  gmail?: boolean;  // Add other integrations here (slack?, telegram?, etc.)
}

/**
 * Install hooks dynamically based on enabled integrations
 */
export function installHooks(workingDir: string, config: HooksConfig): void {
  const hooks: any[] = [];
  const lettaDir = resolve(workingDir, '.letta');
  const hooksDir = resolve(workingDir, 'hooks');

  mkdirSync(lettaDir, { recursive: true });
  mkdirSync(hooksDir, { recursive: true });

  // Gmail security hook
  if (config.gmail) {
    hooks.push({
      matcher: 'Bash',
      hooks: [
        {
          type: 'command',
          command: './hooks/gmail-security.sh',
        },
      ],
    });

    // Copy Gmail hook script
    cpSync(
      resolve(BUNDLED_HOOKS_DIR, 'gmail-security.sh'),
      resolve(hooksDir, 'gmail-security.sh')
    );
  }

  // Future: Add other integration hooks here
  // if (config.slack) { ... }
  // if (config.telegram) { ... }

  // Generate settings.json dynamically
  const settings = {
    hooks: {
      PreToolUse: hooks,
    },
  };

  writeFileSync(
    resolve(lettaDir, 'settings.json'),
    JSON.stringify(settings, null, 2),
    'utf-8'
  );

  const hookNames = [];
  if (config.gmail) hookNames.push('Gmail');

  if (hookNames.length > 0) {
    console.log(`[Hooks] Installed security hooks: ${hookNames.join(', ')}`);
  }
}
