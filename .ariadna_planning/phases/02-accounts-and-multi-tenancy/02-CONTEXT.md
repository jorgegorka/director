# Phase 2: Accounts & Multi-tenancy — Context

## Decisions

### Tenant Routing: Session-based switching
Flat routes (`/roles`, `/agents`, `/settings`) scoped to the active company stored in session. `Current.account` is set via `before_action` from `session[:company_id]`. No path-based company nesting.

**Implication:** Need a `set_current_account` concern in ApplicationController that loads from session. All tenant-scoped controllers inherit this.

### Invitations: Email invitation link
Full invitation flow:
1. Owner enters email + role (admin/member)
2. System creates Invitation record with token
3. System sends email with accept link
4. Recipient clicks link — creates account or logs in — auto-joins company
5. Invitation marked accepted

**Implication:** Need Invitation model, InvitationsController, mailer, and acceptance flow. Existing users who receive invite link should be able to accept without re-registering.

### Company Switching: Nav dropdown switcher
Company name in top nav with dropdown to switch active company. Dropdown shows all user's companies with checkmark on active one, plus "+ New Company" link.

**Implication:** Nav partial needs to load user's companies. Switching sets `session[:company_id]` and redirects to company root.

## Claude's Discretion

- Model naming (`Company` vs `Account` vs `Organization`) — pick what fits best
- Membership join table design (polymorphic roles vs enum vs separate table)
- How to handle "no company selected" state (redirect to company creation? show company list?)
- Invitation expiration policy

## Deferred Ideas

- Subdomain-based routing (not needed for v1)
- Invite codes / shareable links (just email invites for now)
- Company settings/edit page (create + list is sufficient for this phase)
