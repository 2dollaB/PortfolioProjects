"""Generate BeatSync_Admin_Panel_Plan.pdf — the implementation plan deliverable."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak,
    Table, TableStyle,
)

BRAND_RED = colors.HexColor("#E8003D")
DARK = colors.HexColor("#0D0D0F")
GRAY = colors.HexColor("#5A5A70")
LIGHT_BG = colors.HexColor("#F7F7FA")
BORDER = colors.HexColor("#DDDDE8")

OUTPUT = "C:/dev/beatsync/BeatSync_Admin_Panel_Plan.pdf"

doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=A4,
    leftMargin=2 * cm, rightMargin=2 * cm,
    topMargin=2 * cm, bottomMargin=2 * cm,
    title="BeatSync — Admin Panel Implementation Plan",
    author="BeatSync",
)

styles = getSampleStyleSheet()

title_main = ParagraphStyle(
    "TitleMain", parent=styles["Title"],
    fontName="Helvetica-Bold", fontSize=30,
    textColor=DARK, spaceAfter=4, leading=34, alignment=0,
)
title_sub = ParagraphStyle(
    "TitleSub", parent=styles["Title"],
    fontName="Helvetica-Bold", fontSize=18,
    textColor=BRAND_RED, spaceAfter=8, leading=22, alignment=0,
)
subtitle = ParagraphStyle(
    "Subtitle", parent=styles["Normal"],
    fontName="Helvetica", fontSize=11,
    textColor=GRAY, spaceAfter=24, leading=16,
)
h1 = ParagraphStyle(
    "H1", parent=styles["Heading1"],
    fontName="Helvetica-Bold", fontSize=18,
    textColor=DARK, spaceBefore=18, spaceAfter=10, leading=22,
)
h2 = ParagraphStyle(
    "H2", parent=styles["Heading2"],
    fontName="Helvetica-Bold", fontSize=14,
    textColor=BRAND_RED, spaceBefore=12, spaceAfter=6, leading=18,
)
body = ParagraphStyle(
    "Body", parent=styles["Normal"],
    fontName="Helvetica", fontSize=10.5,
    textColor=DARK, spaceAfter=8, leading=15,
)
bullet = ParagraphStyle(
    "Bullet", parent=body,
    leftIndent=14, bulletIndent=0, spaceAfter=4, leading=14,
)
caption = ParagraphStyle(
    "Caption", parent=styles["Normal"],
    fontName="Helvetica-Oblique", fontSize=9,
    textColor=GRAY, spaceAfter=6, leading=12,
)
code = ParagraphStyle(
    "Code", parent=body,
    fontName="Courier", fontSize=9.5,
    textColor=DARK, leftIndent=12, spaceAfter=4, leading=13,
)

story = []

# ── Title block ──
story.append(Paragraph("BeatSync", title_main))
story.append(Paragraph("Admin Panel Implementation Plan", title_sub))
story.append(Paragraph(
    "MVP scope · Next.js · Firebase · Two roles: CEO + Trainer",
    subtitle,
))

# ── Build order ──
story.append(Paragraph("Build order — application first", h1))
story.append(Paragraph(
    "The mobile app is the product. Without it, the admin panel manages nothing. "
    "Wire the Flutter prototype to Firebase first, then build the admin panels on "
    "top of the same backend.",
    body,
))
order_data = [
    ["#", "Phase", "Duration", "Why this order"],
    ["1", "Wire Flutter prototype to Firebase\n(auth · Firestore · BLE · workout save)",
     "3-4 days", "Prototype is half-done — fastest path to a working product"],
    ["2", "Trainer admin panel (Next.js)",
     "2-3 days", "Once trainers exist in Firebase, give them a desktop tool to manage their studio"],
    ["3", "CEO admin panel (Next.js)",
     "1-2 days", "Once a few studios are signed up, you need platform-wide visibility"],
]
order_table = Table(order_data, colWidths=[0.8 * cm, 6 * cm, 2.5 * cm, 7.7 * cm])
order_table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), BRAND_RED),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONT", (0, 0), (-1, 0), "Helvetica-Bold", 10),
    ("FONT", (0, 1), (-1, -1), "Helvetica", 9),
    ("TEXTCOLOR", (0, 1), (-1, -1), DARK),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("ALIGN", (0, 0), (0, -1), "CENTER"),
    ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story.append(order_table)
story.append(Spacer(1, 12))
story.append(Paragraph(
    "<b>Clincher:</b> you can manually onboard your first paying trainer via the Firebase "
    "console (add their studio doc by hand). They can use the mobile app to run their "
    "classes immediately. They don't strictly need the admin panel for week 1. "
    "They <b>do</b> need the mobile app.",
    body,
))

# ── Architecture ──
story.append(Paragraph("Architecture", h1))
story.append(Paragraph("One Next.js codebase. Two route trees:", body))
story.append(Paragraph("admin.beatsync.app/", code))
story.append(Paragraph("├── /login                ← shared", code))
story.append(Paragraph("├── /studio/*             ← Trainer panel  (role: trainer)", code))
story.append(Paragraph("│   ├── /studio           dashboard", code))
story.append(Paragraph("│   ├── /studio/members", code))
story.append(Paragraph("│   ├── /studio/sessions", code))
story.append(Paragraph("│   ├── /studio/billing", code))
story.append(Paragraph("│   └── /studio/settings", code))
story.append(Paragraph("└── /admin/*              ← CEO panel  (role: ceo)", code))
story.append(Paragraph("    ├── /admin            dashboard", code))
story.append(Paragraph("    ├── /admin/studios", code))
story.append(Paragraph("    ├── /admin/users", code))
story.append(Paragraph("    ├── /admin/billing", code))
story.append(Paragraph("    ├── /admin/team", code))
story.append(Paragraph("    └── /admin/audit", code))
story.append(Spacer(1, 6))
story.append(Paragraph(
    "<b>Why one codebase:</b> shared auth, shared design system, shared component "
    "library, shared Firebase SDK setup. Saves a solo dev ~30% of the work. Auth "
    "claims (<font face='Courier'>role</font>, <font face='Courier'>studioId</font>) "
    "decide which routes the user can access.",
    body,
))

# ── Tech stack ──
story.append(PageBreak())
story.append(Paragraph("Tech stack inside Next.js", h1))
tech_data = [
    ["Layer", "Choice", "Why"],
    ["Framework", "Next.js 15 (App Router)", "Server components for fast loads, route handlers for Stripe webhooks later"],
    ["Language", "TypeScript", "Auth claims + Firestore types are unreadable without it"],
    ["Styling", "Tailwind CSS", "Matches BeatSync design tokens fast"],
    ["Components", "shadcn/ui", "Copy-paste, accessible, customizable"],
    ["Tables", "TanStack Table v8", "Industry-standard data grid"],
    ["Forms", "React Hook Form + Zod", "Type-safe form validation"],
    ["State", "TanStack Query", "Cache Firestore data, dedupe requests"],
    ["Backend", "Firebase JS SDK + Admin SDK", "Same backend as the Flutter app"],
    ["Charts", "Recharts", "Simple, clean defaults"],
    ["CSV exports", "papaparse", "One library call"],
    ["Icons", "Lucide React", "Matches the design language"],
]
tech_table = Table(tech_data, colWidths=[3 * cm, 5 * cm, 9 * cm])
tech_table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), DARK),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONT", (0, 0), (-1, 0), "Helvetica-Bold", 10),
    ("FONT", (0, 1), (-1, -1), "Helvetica", 9),
    ("FONT", (1, 1), (1, -1), "Helvetica-Bold", 9),
    ("TEXTCOLOR", (1, 1), (1, -1), BRAND_RED),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
    ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ("TOPPADDING", (0, 0), (-1, -1), 5),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BG]),
]))
story.append(tech_table)

# ── Phase A ──
story.append(Paragraph("Phase A — Foundation", h1))
story.append(Paragraph(
    "<i>Duration: 1 day · Goal: clickable shell with auth, no real data yet</i>",
    caption,
))
for item in [
    "Init Next.js project, Tailwind, shadcn/ui base components",
    "Port BeatSync design tokens (brand red, dark theme, zone colors) into Tailwind config",
    "Firebase JS SDK config + auth provider context",
    "Auth pages: /login with brand red logo + email/password — same visual language as Flutter login",
    "Role-based route guard middleware: reads custom claims from ID token",
    "Trainer layout: sidebar (Dashboard / Members / Sessions / Billing / Settings) + top bar",
    "CEO layout: sidebar (Dashboard / Studios / Users / Billing / Team / Audit / Config) + top bar",
    "Shared components scaffold: DataTable, PageShell, EmptyState, LoadingSkeleton, ConfirmDialog, Toast",
]:
    story.append(Paragraph(f"• {item}", bullet))
story.append(Paragraph(
    "<b>Deliverable:</b> log in as trainer or CEO and land on the correct empty dashboard.",
    body,
))

# ── Phase B ──
story.append(PageBreak())
story.append(Paragraph("Phase B — Trainer Panel", h1))
story.append(Paragraph(
    "<i>Duration: 1.5-2 days · Goal: trainer can run their studio from desktop</i>",
    caption,
))
phase_b = [
    ("Dashboard", "this week's session count, active members, upcoming sessions list, quick CTAs"),
    ("Members table", "search, filter, sortable columns (name, email, attendance, last seen, joined date)"),
    ("Member detail page", "profile, attendance heatmap, fitness trend chart, notes field, action menu (remove, message)"),
    ("Invite members", "modal with email invite, shareable link, QR code download, CSV bulk upload"),
    ("Sessions list", "past sessions table with date, type, athlete count, avg TRIMP"),
    ("Session detail", "per-athlete breakdown (BPM, zone time, position), export as PDF"),
    ("Session scheduler", "calendar view + create-session form (one-off + recurring)"),
    ("Studio settings", "studio name, member capacity, invite code regenerate, TV view URL with QR"),
    ("Billing", "scaffolded only for MVP — shows current tier + member usage bar. Stripe wiring later."),
    ("Account settings", "email change, password change, sign out"),
]
for i, (title, desc) in enumerate(phase_b, 1):
    story.append(Paragraph(f"<b>{i}. {title}</b> — {desc}", bullet))
story.append(Paragraph(
    "<b>Deliverable:</b> functional trainer admin panel with real Firestore data. "
    "Ship to your first paying studio.",
    body,
))

# ── Phase C ──
story.append(Paragraph("Phase C — CEO Panel", h1))
story.append(Paragraph(
    "<i>Duration: 1-1.5 days · Goal: you and your brothers can monitor + support the platform</i>",
    caption,
))
phase_c = [
    ("Dashboard", "KPIs: total active studios + trend, total athletes, sessions this week, recent signups"),
    ("Studios table", "all studios with status, plan, member count, last active. Search + filter."),
    ("Studio detail", "read-only mirror of trainer view. Actions: suspend / restore / comp / add note"),
    ("Users table", "all users across studios. Role filter (trainer/athlete), studio filter, status filter"),
    ("User detail", "profile, workouts, devices, login history. Actions: ban, restore, password reset, impersonate"),
    ("Team management", "invite a CEO (you + brothers), remove access. All CEOs have equal permissions."),
    ("Audit log", "every destructive action recorded. Filterable by CEO, action type, date"),
    ("Configuration", "global feature flags, maintenance mode, minimum app version"),
]
for i, (title, desc) in enumerate(phase_c, 1):
    story.append(Paragraph(f"<b>{i}. {title}</b> — {desc}", bullet))
story.append(Paragraph(
    "<i>Skip for MVP: platform analytics, communications, deep billing tools. Add post-launch.</i>",
    caption,
))
story.append(Paragraph(
    "<b>Deliverable:</b> you can sit at your laptop and understand what's happening "
    "across every studio.",
    body,
))

# ── Phase D ──
story.append(PageBreak())
story.append(Paragraph("Phase D — Backend Tie-in", h1))
story.append(Paragraph(
    "<i>Runs alongside Phase B + C — admin panels are useless without it</i>",
    caption,
))
story.append(Paragraph("<b>Data model</b>", h2))
for item in [
    "Firestore collections finalized (users, studios, sessions, workouts, audit_log)",
    "Indexes for the filterable tables",
    "TypeScript types generated from Firestore schema",
]:
    story.append(Paragraph(f"• {item}", bullet))

story.append(Paragraph("<b>Authentication & permissions</b>", h2))
for item in [
    "Firebase Auth custom claims via Admin SDK: { role: 'athlete' | 'trainer' | 'ceo', studioId? }",
    "Athletes read/write own user doc + workouts only",
    "Trainers read/write their own studio + its members + its sessions",
    "CEOs read everything; writes go through Cloud Functions only (auditable)",
    "Only two admin-panel roles: trainer (per studio) and ceo (you + brothers, equal access)",
]:
    story.append(Paragraph(f"• {item}", bullet))

story.append(Paragraph("<b>Cloud Functions</b>", h2))
for item in [
    "inviteAthleteToStudio — generates invite code, validates trainer",
    "suspendStudio — bulk-disables a studio (CEO only)",
    "impersonateUser — generates short-lived token (CEO only)",
    "logAdminAction — every destructive action goes through this for the audit log",
]:
    story.append(Paragraph(f"• {item}", bullet))

story.append(Paragraph(
    "<b>Deliverable:</b> the admin panel actually does things, securely.",
    body,
))

# ── Timeline ──
story.append(Paragraph("Realistic timeline", h1))
timeline_data = [
    ["Day", "Work"],
    ["Day 1", "Phase A (foundation) + start Phase D (data model)"],
    ["Day 2", "Phase B parts 1–5 (dashboard, members, invites, sessions)"],
    ["Day 3", "Phase B parts 6–10 (session detail, scheduler, settings, billing scaffold, account)"],
    ["Day 4", "Phase C parts 1–5 (CEO dashboard, studios, users, impersonate)"],
    ["Day 5", "Phase C parts 6–8 (team, audit, config) + Phase D wrap-up (security rules, indexes)"],
]
timeline_table = Table(timeline_data, colWidths=[2.5 * cm, 14.5 * cm])
timeline_table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), BRAND_RED),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONT", (0, 0), (-1, 0), "Helvetica-Bold", 10),
    ("FONT", (0, 1), (-1, -1), "Helvetica", 10),
    ("FONT", (0, 1), (0, -1), "Helvetica-Bold", 10),
    ("TEXTCOLOR", (0, 1), (-1, -1), DARK),
    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ("GRID", (0, 0), (-1, -1), 0.5, BORDER),
    ("LEFTPADDING", (0, 0), (-1, -1), 8),
    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BG]),
]))
story.append(timeline_table)
story.append(Spacer(1, 10))
story.append(Paragraph(
    "<b>~5 working days</b> for both panels to a launchable MVP — meaning you can "
    "sign up a paying trainer and run them through their studio panel without embarrassment.",
    body,
))

# ── MVP summary ──
story.append(Paragraph("What ships as the MVP launch", h1))
story.append(Paragraph(
    "<b>Trainer panel:</b> 100% of Phase B (all ten features above)",
    body,
))
story.append(Paragraph(
    "<b>CEO panel:</b> dashboard + studios + users + team + audit "
    "(skip analytics, communications, deep billing for MVP)",
    body,
))
story.append(Paragraph(
    "Everything else (communications, deep analytics, Stripe wiring, exports) is "
    "post-launch — added once you have a paying studio asking for it.",
    body,
))

# ── Footer ──
story.append(Spacer(1, 28))
story.append(Paragraph(
    "BeatSync · Solo developer · MVP build phase",
    caption,
))

doc.build(story)
print(f"PDF generated: {OUTPUT}")
