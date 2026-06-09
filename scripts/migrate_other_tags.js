/*
Migration script for Smart_pocket
- Converts account tags that are missing or set to 'OTHER' into recommended tags
  (INVESTMENT / SAVINGS / DAILY_USE) using provider/type heuristics.
- Sets user.settings.app_mode_origin to 'detailed' if user has any non-lazy_* accounts,
  otherwise 'lazy'.
- Writes audit logs under collection `migration_audits` and per-user `migration_audits/{userId}/changes`.

Usage:
  - Ensure you have a Firebase service account JSON and set env var:
      set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccount.json
  - From repository root, run:
      node scripts/migrate_other_tags.js --project your-gcp-project-id [--dryRun]

Options:
  --dryRun   : do not write changes, only print what would change
  --project  : (optional) Firestore project id if not specified in service account
*/

const admin = require('firebase-admin');
const yargs = require('yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
  .option('dryRun', { type: 'boolean', default: false })
  .option('project', { type: 'string' })
  .argv;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
  process.exit(1);
}

const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);
const proj = argv.project || serviceAccount.project_id;

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: proj,
});

const db = admin.firestore();

// Heuristic mapping
const investmentProviders = new Set([
  'asnb', 'versa', 'moomoo malaysia', 'fsmone', 'tabung haji', 'sspn', 'kwsp', 'kwsp / epf', 'stashaway'
]);

function recommendTagFor(account) {
  const type = (account.type || '').toString().trim().toLowerCase();
  const provider = (account.provider || account.name || '').toString().trim().toLowerCase();

  if (type === 'investment' || investmentProviders.has(provider)) return 'INVESTMENT';
  if (type === 'ewallet') return 'DAILY_USE';
  if (type === 'cash') return 'DAILY_USE';
  // default for banks
  if (type === 'bank') return 'SAVINGS';
  // fallback
  // if provider looks like ewallet keywords
  if (provider.includes('tng') || provider.includes('touch') || provider.includes('ewallet') || provider.includes('grab')) return 'DAILY_USE';
  if (provider.includes('maybank') || provider.includes('cimb') || provider.includes('bank')) return 'SAVINGS';

  return 'SAVINGS';
}

(async () => {
  console.log('Starting migration (dryRun=%s) project=%s', argv.dryRun, proj);

  const usersSnap = await db.collection('users').get();
  console.log('Found %d users', usersSnap.size);

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const userData = userDoc.data() || {};
    const settings = (userData.settings || {});

    // read accounts
    const accountsRef = db.collection('users').doc(uid).collection('accounts');
    const accSnap = await accountsRef.get();

    const hasDetailed = accSnap.docs.some(d => !d.id.startsWith('lazy_'));
    const origin = hasDetailed ? 'detailed' : 'lazy';

    if (argv.dryRun) {
      if (!settings || !settings.app_mode_origin || settings.app_mode_origin !== origin) {
        console.log(`[DRY] Would set user ${uid} app_mode_origin => ${origin}`);
      }
    } else {
      const payload = { 'settings.app_mode_origin': origin, 'settings.app_mode': settings.app_mode || 'lazy', 'updated_at': admin.firestore.FieldValue.serverTimestamp() };
      await db.collection('users').doc(uid).set(payload, { merge: true });
      console.log(`Updated user ${uid} app_mode_origin => ${origin}`);
    }

    for (const aDoc of accSnap.docs) {
      const a = aDoc.data() || {};
      const tagRaw = (a.tag || '').toString().trim();
      const tagUpper = tagRaw.toUpperCase();

      if (!tagRaw || tagUpper === 'OTHER') {
        const recommended = recommendTagFor(a);
        if (argv.dryRun) {
          console.log(`[DRY] user=${uid} account=${aDoc.id} tag: '${tagRaw}' -> '${recommended}'`);
        } else {
          try {
            await accountsRef.doc(aDoc.id).update({ tag: recommended });
            // write audit log
            const auditRef = db.collection('migration_audits').doc();
            await auditRef.set({
              user_id: uid,
              account_id: aDoc.id,
              old_tag: tagRaw || null,
              new_tag: recommended,
              migrated_at: admin.firestore.FieldValue.serverTimestamp(),
            });
            // also write per-user audit record
            const perUserRef = db.collection('users').doc(uid).collection('migration_audits').doc();
            await perUserRef.set({
              account_id: aDoc.id,
              old_tag: tagRaw || null,
              new_tag: recommended,
              migrated_at: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Migrated user=${uid} account=${aDoc.id} tag '${tagRaw}' -> '${recommended}'`);
          } catch (e) {
            console.error(`Failed to migrate account ${aDoc.id} for user ${uid}:`, e);
          }
        }
      }
    }
  }

  console.log('Migration completed.');
  process.exit(0);
})();
