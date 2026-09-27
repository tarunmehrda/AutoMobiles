# GarageSaarthi, read critically — and what we do instead

Written as the design brief for the desktop console. The 64 screenshots are a
**feature inventory**, not a style guide: they tell us what a workshop needs, not what
it should look like. This is where the two part company.

---

## The eight things the reference app gets wrong

### 1. It is a phone app with a desktop build bolted on

Every screen is one narrow column. On a 1440-wide window that is a strip of content in an
ocean of grey, and the owner scrolls for things that would fit on one screen.

**Instead:** layouts declare a *shape*, not a width. Below 900 px, one column and a bottom
bar. Above it, a persistent rail and two panes — list on the left, detail on the right —
so opening a job card does not lose the list you were reading.

### 2. Dark sign-in, light app

The login screen is near-black; every screen behind it is white. The first thing the
product does is contradict itself.

**Instead:** one surface, one temperature. The sign-in screen is the app with nothing in
it yet, not a different product.

### 3. Ceremony where there should be typing

Four steps and ~40 inputs to open a job card. An OTP to prove a phone number that nobody
will ever send a code to again. A four-card permission tour that requests nothing.

**Instead:** one screen with four collapsing sections. No OTP — this console is used from
a desk, and a code sent to a handset is a hurdle between somebody and software they have
already paid for. Permissions are asked for at the moment they are used, where the reason
is on screen.

### 4. It never once considers a keyboard

No autofocus. No Enter to submit. No Tab order worth the name. No shortcuts. On a PC that
is not a small omission — it is the difference between forty job cards a day and twelve.

**Instead, the desktop console owes the counter:**

| | |
|---|---|
| `Ctrl+N` | new job card |
| `Ctrl+K` | search everything — plate, name, mobile, card number |
| `Ctrl+S` | save whatever is open |
| `Enter` | the primary action of the focused form |
| `Esc` | close the sheet, cancel the edit |
| `F2` | edit the selected row |
| `/` | jump to the filter box |

Plus: first field autofocused on every screen, Tab visiting fields in the order a person
fills them, and a visible focus ring — because a keyboard user who cannot see where they
are is worse off than one with no keyboard support at all.

### 5. Decorative charts

Two flat sparklines with no axis, no tooltip, no range. They are a picture of a chart.

**Instead:** if a chart cannot be interrogated — hover for the number, change the range,
click through to the rows behind it — it should be a number in large type instead. Fewer
charts, each one answering a question the owner actually asks.

### 6. Modal soup

Add Customer exists as both a bottom sheet and a full page. Two code paths, four fields.
On desktop a bottom sheet is simply wrong — it is a phone gesture rendered on a monitor.

**Instead:** one surface per task. On desktop it is a centred dialog or an inline panel;
on phone the same thing is a sheet. The *content* is written once.

### 7. Padding where density belongs

Every list is a stack of cards with 16 px of air. On a phone that is right. On a monitor
it means six rows where thirty would fit, and a counter scrolling past what they can see.

**Instead:** at desktop width, lists become tables — sortable columns, a selected row, and
the detail beside them. The card layout is kept for phone, from the same data.

### 8. No sense of place

Everything is a stack you push onto and pop off. No breadcrumb, no persistent navigation,
no way to know where you are or get back in one move.

**Instead:** the rail is always visible and always says where you are.

---

## What we keep from it

Credit where it is due — these are good, and copying them is the right call:

- **The complaints picker.** A checklist of preset complaints in the customer's own words
  is the fastest input on the floor. Kept verbatim.
- **Purchase entry and part-master creation as one screen.** Several items sharing one
  supplier invoice matches how a workshop actually receives stock.
- **The drawer's module tree.** It is an accurate map of what a garage does.
- **Insurance as a first-class flag** on a job card, driving a different payer and series.

---

## The animation language

Not the reference app's. Theirs is a static photo behind a dark card.

Three rules:

1. **Motion explains a change, or it does not happen.** Something enters from where it
   came from and leaves towards where it went. Nothing animates to be noticed.
2. **Under 240 ms, or it is in the way.** A counter opening their fortieth card of the day
   should never wait on a flourish. Everything is interruptible.
3. **One idle motion per screen, at most** — and only where there is genuinely nothing to
   do yet, like the sign-in screen.

The idle motion on sign-in is the **bay**: two or three slow diagonal light bars drifting
across a dark ground, the way overhead strip lights pass over a car being rolled into a
workshop. Slow enough to be atmosphere rather than a loop you notice — 20 s or more per
pass — and it stops as soon as a field has focus.

---

## Status

Done so far: the OTP step is gone, permissions are asked where they are used, and
"Use Current Location" actually works instead of showing a toast.

**Not yet done: the desktop layout and the visual direction above.** Holding it until
your examples arrive — building a whole visual language now and replacing it when they
land wastes the work. The structural items (responsive shape, keyboard map, tables at
width) are independent of style and can start whenever you say.
