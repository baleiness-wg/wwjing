const itemModel = require("../models/bookmark-item.model");
const metadataService = require("./bookmark-metadata.service");
const logger = require("../logger");

let running = false;

async function refreshMissingCovers() {
  if (running) return;
  running = true;
  let scanned = 0;
  let updated = 0;
  try {
    const items = await itemModel.findItemsMissingImages(100);
    for (const item of items) {
        scanned += 1;
        try {
          const metadata = await metadataService.fetchMetadata({ sourceUrl: item.sourceUrl });
          if (metadata?.coverUrl) {
            await itemModel.updateImages(item.id, [metadata.coverUrl]);
            updated += 1;
          }
        } catch (error) {
          logger.warn({ itemId: item.id, code: error.code }, "scheduled cover refresh skipped item");
        }
    }
    logger.info({ scanned, updated }, "scheduled cover refresh completed");
  } catch (error) {
    logger.error({ err: error, scanned, updated }, "scheduled cover refresh failed");
  } finally {
    running = false;
  }
}

function scheduleCoverRefresh() {
  const scheduleNext = () => {
    const now = new Date();
    const next = new Date(now);
    next.setHours(4, 0, 0, 0);
    if (next <= now) next.setDate(next.getDate() + 1);
    const delay = next.getTime() - now.getTime();
    setTimeout(async () => {
      await refreshMissingCovers();
      scheduleNext();
    }, delay).unref?.();
    logger.info({ nextRunAt: next.toISOString() }, "scheduled cover refresh registered");
  };
  scheduleNext();
}

module.exports = { refreshMissingCovers, scheduleCoverRefresh };
