# Artwork bundled into the app

Everything in this folder ships inside the binary, so only add files whose
licence allows redistribution inside a product, and record the source here
before you add them.

## unDraw illustrations (`art_*.svg`)

| Field | Value |
| ----- | ----- |
| Author | Katerina Limpitsouni |
| Home | <https://undraw.co> |
| Pulled from | <https://github.com/mkhairi/undraw> — `vendor/assets/images/undraw/` |
| Licence | unDraw licence — free for commercial and non-commercial use, no attribution required |

unDraw's licence allows using the illustrations inside a product like this
one. What it does not allow is redistributing the *collection* as a product of
its own, or shipping something whose value is the illustrations themselves.
Neither describes a workshop console that draws an empty box when a stock list
has nothing in it, so this use is within terms. Check
<https://undraw.co/license> before a store release all the same.

### What was changed

unDraw draws every illustration in exactly one brand colour, `#6c63ff`. Each
file here has had that hex substituted for the app's signal orange,
`#FF5F2E`, and is otherwise byte-for-byte upstream.

The substitution happened once, on the way in, rather than at render time —
so **the orange is baked in**. If `AppPalette.accent` ever moves, re-run the
fetch rather than expecting these to follow.

| File | unDraw name | Used for |
| ---- | ----------- | -------- |
| `art_vehicle.svg` | `by_my_car` | Job card masthead |
| `art_vehicle_sale.svg` | `vehicle_sale` | Vehicle lookup |
| `art_maintenance.svg` | `maintenance` | Service and handover |
| `art_empty.svg` | `empty` | Generic empty list |
| `art_no_data.svg` | `no_data` | Empty report or chart |
| `art_searching.svg` | `file_searching` | Search with no matches |
| `art_invoice.svg` | `printing_invoices` | Bills and reports |
| `art_wallet.svg` | `wallet` | Money, balances, cashbook |
| `art_done.svg` | `order_confirmed` | Success and completion |
| `art_stock.svg` | `add_to_cart` | Inventory and stock |
| `art_customers.svg` | `people_search` | Customers and staff |
| `art_delivery.svg` | `delivery` | Suppliers and purchase orders |
