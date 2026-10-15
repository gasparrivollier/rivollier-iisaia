import { expect, type Locator, type Page } from '@playwright/test';

/** A Flutter widget wrapped in `Semantics(identifier: id)`. Needs an E2E=true build. */
export function byId(page: Page, id: string): Locator {
  return page.locator(`[flt-semantics-identifier="${id}"]`);
}

/**
 * Types into a Flutter text field. Clicking the semantics node focuses Flutter's
 * hidden editing <input>; keyboard events then go through Flutter's text input.
 * Probe result (slice 0.2): the identifier lands on a <flt-semantics> wrapper that contains
 * the <input>; clicking it focuses the input, so click + keyboard.type works as-is.
 * Note: error text also appears in Flutter's aria-live <flt-announcement-polite>, so assert
 * text scoped to a byId node, not page-wide getByText.
 */
export async function fillField(page: Page, id: string, value: string): Promise<void> {
  await byId(page, id).click();
  // Typing right after the click can drop the first characters (seen on the obscured
  // password field) because Flutter swaps in its editing <input> asynchronously.
  await expect(byId(page, id).locator('input, textarea')).toBeFocused();
  await page.keyboard.type(value);
  await expect(byId(page, id).locator('input, textarea')).toHaveValue(value);
}
