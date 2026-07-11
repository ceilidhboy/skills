---
name: inertia-react-conventions
description: React component architecture and project conventions for Inertia.js v2 applications. Covers directory structure, structural vs markup components, DRY patterns, prop naming, and project-specific patterns.
author: Mike Scott
version: '1.0.0'
updated: '2026-07-11'
---

# Inertia.js v2 + React Development

## When to Activate This Skill

Activate this skill whenever you are:
- Creating or modifying React pages in `resources/js/pages/`
- Creating or modifying React components in `resources/js/components/`
- Working with Inertia.js patterns like `<Link>`, `<Form>`, `useForm`, or `router`
- Implementing deferred props, infinite scrolling, lazy loading, polling, or prefetching
- Working with TypeScript in React components
- Organizing component structure and imports

## Component Organization Structure

### Directory Hierarchy

Components are organized hierarchically based on ownership and reusability:

```
resources/js/components/
├── clients/                      # Page-specific components (kebab-case directory)
│   ├── index.ts                  # Barrel export
│   ├── SearchBar.tsx             # Parent component (PascalCase)
│   ├── search-bar/               # Subcomponents directory (kebab-case)
│   │   ├── index.ts
│   │   └── SearchInput.tsx       # Subcomponent (PascalCase)
│   ├── Table.tsx                 # Parent component (PascalCase)
│   └── table/                    # Subcomponents directory (kebab-case)
│       ├── index.ts
│       ├── TableRow.tsx          # Subcomponent (PascalCase)
│       ├── TableCell.tsx         # Subcomponent (PascalCase)
│       └── table-row/            # Nested subcomponents (kebab-case)
│           ├── index.ts
│           └── TableRowActions.tsx
├── shared/                       # Shared components (used across pages)
│   ├── NavMain.tsx
│   └── NavFooter.tsx
└── ui/                           # UI primitives (shadcn/ui, etc.)
    ├── Button.tsx
    └── Card.tsx

resources/js/pages/
├── Clients.tsx                   # Page component (PascalCase)
└── Dashboard.tsx
```

**Key Pattern**: The parent component file is a **peer** of its subcomponent directory, not inside it.
- ✅ `SearchBar.tsx` is a peer of `search-bar/` directory
- ✅ `Table.tsx` is a peer of `table/` directory
- ❌ NOT `SearchBar.tsx` inside `search-bar/` directory

### Naming Conventions

- **Directories**: Always kebab-case (e.g., `clients`, `search-bar`, `table`)
- **Component Files**: PascalCase, matching the component function name (e.g., `SearchBar.tsx`, `Table.tsx`)
  - ✅ `SearchBar.tsx` exports `function SearchBar() { ... }`
  - ✅ `Table.tsx` exports `function Table() { ... }`
  - ❌ NOT `search-bar.tsx` (kebab-case files are for utilities, not components)
- **Page Files**: PascalCase (e.g., `Dashboard.tsx`, `Clients.tsx`)
- **Utility/Helper Files**: kebab-case (e.g., `format-date.ts`, `api-client.ts`)
- **Component Functions**: PascalCase, drop redundant prefixes
  - ✅ `SearchBar` (not `ClientsSearchBar`)
  - ✅ `Table` (not `ClientsTable`)
- **Types**: PascalCase with `Props` suffix (e.g., `SearchBarProps`)

### Barrel Exports

Every component directory must have an `index.ts` file:

```typescript
// resources/js/components/clients/index.ts
export { SearchBar } from './SearchBar';
export { Table } from './table';
```

This enables clean imports:
```typescript
import { SearchBar, Table } from '@/components/clients';
```

### Recursive Subcomponent Structure

If a component has subcomponents, create a kebab-cased subdirectory alongside the parent component file. The parent component is a **peer** of its subcomponent directory:

**Correct Structure:**
```
resources/js/components/dashboard/
├── Campaigns.tsx                    # ✅ Parent component (PascalCase)
├── campaigns/                       # ✅ Subcomponents directory (kebab-case)
│   ├── index.ts
│   ├── Cards.tsx
│   └── cards/                       # Nested subcomponents
│       ├── index.ts
│       ├── Card.tsx
│       └── card/
│           ├── index.ts
│           └── CardActions.tsx
├── RecentActivity.tsx               # ✅ Parent component (PascalCase)
└── recent-activity/                 # ✅ Subcomponents directory (kebab-case)
    ├── index.ts
    ├── Layout.tsx
    ├── Header.tsx
    ├── Activities.tsx
    └── activity-item/               # Nested subcomponents
        ├── index.ts
        ├── ActivityItem.tsx
        └── Icon.tsx
```

**Incorrect Structure (DO NOT DO THIS):**
```
resources/js/components/dashboard/recent-activity/
├── ActivityItem.tsx                 # ❌ WRONG: Parent inside its own directory
├── activity-item/
│   ├── Icon.tsx
│   └── index.ts
└── ...
```

The parent component file should always be at the same level as its kebab-case subcomponent directory.

### Layout File Naming

Layout components should **always** be named `Layout.tsx` — never prefixed with the parent component name.

**Correct:**
```
├── RecentActivity.tsx
└── recent-activity/
    ├── Layout.tsx         # ✅ Just "Layout", no prefix
    └── Header.tsx
```

**Incorrect:**
```
├── RecentActivity.tsx
└── recent-activity/
    ├── RecentActivityLayout.tsx   # ❌ WRONG: Redundant prefix
    └── Header.tsx
```

The prefix is redundant because the file is already inside the `recent-activity/` directory — context is clear from the path.

## Component Composition Architecture: Structural Components vs. Markup Components

React components should follow a clear architectural pattern that separates concerns and keeps components focused and maintainable. There are two fundamental types of components:

### 1. Structural Components (Pure Composition)

**Goal**: Structural components should aim to be **entirely composed of subcomponents with zero HTML markup**. They are the "glue" that connects and coordinates subcomponents.

**Purpose**: Structural components determine the **relationships between components** in the application. They define how components connect, what data flows between them, and how they interact. The actual rendering of those relationships is delegated to markup components. This separation means:
- **Structural components** handle composition and relationships, i.e. the high-level structure of the application
- **Markup components** handle rendering and HTML structure

**Characteristics:**
- Import and compose subcomponents
- Handle data flow and state management
- Pass props to subcomponents
- Determine component relationships and hierarchy
- **No HTML elements** (no `<div>`, `<span>`, `<p>`, etc.)
- No inline styling or Tailwind classes
- Purely compositional - reads like a blueprint of the component structure

**Example: Structural Component**
```typescript
// ✅ GOOD: Pure composition, no HTML markup
export function RecentActivity({ activities }: RecentActivityProps) {
    return (
        <Layout>
            <Header title="Recent Activity" />
            <Activities items={activities} />
        </Layout>
    );
}
```

**Bad Example: Structural component with HTML Markup**
```typescript
// ❌ BAD: Mixing composition with HTML markup
export function RecentActivity({ activities }: RecentActivityProps) {
    return (
        <div className="space-y-4">
            <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold">Recent Activity</h2>
            </div>
            <Activities items={activities} />
        </div>
    );
}
```

### 2. Markup Components (HTML Structure)

Markup components contain the actual HTML elements and styling. They appear in two places in the component hierarchy:

#### A. Layout Components

Layout components wrap other components and provide the HTML structure, spacing, and styling. They are typically peers of the Structural component in the subcomponent directory.

**Characteristics:**
- Contain HTML wrapper elements (`<div>`, `<section>`, etc.)
- Apply spacing, layout, and structural styling
- Accept `children` prop to wrap subcomponents
- Keep markup focused on layout, not content

**Example: Layout Component**
```typescript
// resources/js/components/dashboard/recent-activity/Layout.tsx
export function Layout({ children }: { children: ReactNode }) {
    return (
        <div className="space-y-4 rounded-lg border border-slate-200 bg-white p-6 dark:border-slate-700 dark:bg-slate-800">
            {children}
        </div>
    );
}
```

#### B. Leaf Node Components

Leaf nodes are the deepest level of the component hierarchy. They contain the actual HTML elements that render content (text, icons, buttons, etc.).

**Characteristics:**
- Contain HTML elements that display content
- Apply styling to individual elements
- No subcomponents (or only UI primitives like `<Button>`, `<Badge>`)
- Focused on rendering a single piece of content
- **CRITICAL**: Extract repeated markup patterns into reusable leaf components to avoid duplication

**Example: Leaf Node Component**
```typescript
// resources/js/components/dashboard/recent-activity/activity-item/ActivityItem.tsx
export function ActivityItem({ activity }: ActivityItemProps) {
    return (
        <div className="flex items-start gap-3 border-b border-slate-200 pb-3 last:border-b-0 dark:border-slate-700">
            <Icon type={activity.type} />
            <div className="flex-1">
                <p className="text-sm font-medium text-slate-900 dark:text-white">
                    {activity.title}
                </p>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                    {activity.timestamp}
                </p>
            </div>
        </div>
    );
}
```

**Example: Extracting Repeated Markup Patterns**

When you notice the same markup structure repeating multiple times, extract it into a reusable leaf component:

```typescript
// ❌ BAD: Massive duplication - same markup repeated 4 times
export function JobDetails({ job }: JobDetailsProps) {
    return (
        <div className="flex flex-col gap-6">
            {/* Company - repeated structure */}
            <div className="flex items-start gap-3">
                <IconSquare icon={Building2} size="md" rounded="md" />
                <div>
                    <p className="text-xs font-medium text-slate-500">Company</p>
                    <p className="mt-1 text-sm text-slate-900">{job.company.name}</p>
                    <p className="text-xs text-slate-600">{job.company.site}</p>
                </div>
            </div>

            {/* Address - SAME STRUCTURE DUPLICATED */}
            <div className="flex items-start gap-3">
                <IconSquare icon={MapPin} size="md" rounded="md" />
                <div>
                    <p className="text-xs font-medium text-slate-500">Address</p>
                    <p className="mt-1 text-sm text-slate-900">{job.company.address}</p>
                </div>
            </div>

            {/* Due Date - SAME STRUCTURE DUPLICATED */}
            <div className="flex items-start gap-3">
                <IconSquare icon={Calendar} size="md" rounded="md" />
                <div>
                    <p className="text-xs font-medium text-slate-500">Due Date</p>
                    <p className="mt-1 text-sm text-slate-900">{job.dueDateForPlacement}</p>
                </div>
            </div>

            {/* Duration - SAME STRUCTURE DUPLICATED */}
            <div className="flex items-start gap-3">
                <IconSquare icon={Clock} size="md" rounded="md" />
                <div>
                    <p className="text-xs font-medium text-slate-500">Duration</p>
                    <p className="mt-1 text-sm text-slate-900">{job.duration}</p>
                </div>
            </div>
        </div>
    );
}
```

**Problem with the above:**
- Any change to the icon styling requires 4 edits
- Any change to the text styling requires 4 edits
- Hard to maintain consistency
- Violates DRY principle

```typescript
// ✅ GOOD: Extract the repeated pattern into a reusable leaf component
// resources/js/components/job/job-information/InformationItem.tsx
type InformationItemProps = {
    icon: LucideIcon;
    label: string;
    children: ReactNode;
};

export function InformationItem({ icon, label, children }: InformationItemProps) {
    return (
        <div className="flex items-start gap-3">
            <IconSquare icon={icon} size="md" rounded="md" bgColor="bg-slate-400/25" iconColor="text-slate-600" />
            <div>
                <p className="text-xs font-medium text-slate-500 dark:text-slate-400">
                    {label}
                </p>
                <div className="mt-1 text-sm text-slate-900 dark:text-white">
                    {children}
                </div>
            </div>
        </div>
    );
}

// Now use it in JobDetails - clean and DRY
export function JobDetails({ job }: JobDetailsProps) {
    return (
        <div className="flex flex-col gap-6">
            <InformationItem icon={Building2} label="Company">
                <p>{job.company.name}</p>
                <p className="text-xs text-slate-600 dark:text-slate-400">{job.company.site}</p>
            </InformationItem>

            <InformationItem icon={MapPin} label="Address">
                <p>{job.company.address}</p>
            </InformationItem>

            <InformationItem icon={Calendar} label="Due Date for Placement">
                <p>{job.dueDateForPlacement}</p>
            </InformationItem>

            <InformationItem icon={Clock} label="Duration">
                <p>{job.duration}</p>
            </InformationItem>
        </div>
    );
}
```

**Benefits:**
- Single source of truth for the markup structure
- Changes to styling only need to be made once
- Easy to maintain consistency
- Follows DRY principle
- Makes the parent component more readable

### Component Hierarchy Example

Here's how these three types work together:

```
RecentActivity.tsx (Structural - Pure Composition)
├── Layout.tsx (Markup - Layout Component)
├── Header.tsx (Markup - Leaf Node)
├── Activities.tsx (Structural - Composes ActivityItem)
│   └── activity-item/
│       ├── ActivityItem.tsx (Markup - Leaf Node)
│       └── Icon.tsx (Markup - Leaf Node)
```

**Reading the Structural component tells you the structure:**
```typescript
// RecentActivity.tsx - You can see the entire structure at a glance
export function RecentActivity({ activities }: RecentActivityProps) {
    return (
        <Layout>
            <Header title="Recent Activity" />
            <Activities items={activities} />
        </Layout>
    );
}
```

### Benefits of This Architecture

1. **Clarity**: Structural components are easy to understand - they show the structure without HTML noise
2. **Maintainability**: Changes to layout or styling are isolated in layout/leaf components
3. **Reusability**: Subcomponents can be reused in different contexts
4. **Testability**: Each component has a single responsibility
5. **Scalability**: Easy to add new subcomponents without cluttering the orchestrator

### When to Create a Layout Component

Create a layout component when:
- Multiple subcomponents need to be wrapped in the same HTML structure
- The wrapper has styling or spacing that's specific to that component
- You want to keep the orchestrator purely compositional

**Example: When to extract a layout component**
```typescript
// ❌ BAD: Structural component has HTML markup
export function JobInformation({ job }: JobInformationProps) {
    return (
        <div className="space-y-8">
            <div className="flex gap-6">
                <JobDetails job={job} />
                <Description description={job.description} />
            </div>
            <RequiredSkills skills={job.requiredSkills} />
        </div>
    );
}

// ✅ GOOD: Extract layout, keep orchestrator pure
export function JobInformation({ job }: JobInformationProps) {
    return (
        <Layout>
            <JobDetails job={job} />
            <Description description={job.description} />
            <RequiredSkills skills={job.requiredSkills} />
        </Layout>
    );
}

// resources/js/components/job/job-information/Layout.tsx
export function Layout({ children }: { children: ReactNode }) {
    return (
        <div className="space-y-8">
            {children}
        </div>
    );
}
```

## Key Principles

1. **Clear Ownership**: Page-specific components grouped with their page
2. **Minimal Naming**: Hierarchical structure allows dropping redundant prefixes
3. **Clean Imports**: Barrel exports eliminate long import paths
4. **Scalability**: Easy to add new pages and components
5. **Reusability**: Shared components clearly separated

## DRY Principle: Avoid Code Duplication

**CRITICAL**: Never create duplicate or near-duplicate code. Always extract common code into reusable components, functions, or utilities.

### When to Extract Common Code

Extract common code when you notice:
- **Identical or near-identical JSX structures** across multiple components
- **Repeated logic patterns** (e.g., pagination controls, form handling, data filtering)
- **Duplicate styling patterns** that appear in multiple places
- **Similar prop handling** across different components

### How to Extract Common Code

#### 1. **Extract Components for Shared UI Patterns**

When multiple components have similar JSX structures, extract a reusable component and parameterize the differences.

**Bad: Duplicate pagination controls in two different components**
```typescript
// Campaigns.tsx
<div className="flex items-center gap-2">
    <span className="text-xs font-medium bg-slate-200 px-2 py-1 rounded-full">
        {campaigns.total}
    </span>
    <div className="flex items-center gap-1">
        <Link href={onPreviousUrl} disabled={currentPage === 1}>
            <ChevronLeft className="h-4 w-4" />
        </Link>
        <span>{currentPage}/{lastPage}</span>
        <Link href={onNextUrl} disabled={currentPage === lastPage}>
            <ChevronRight className="h-4 w-4" />
        </Link>
    </div>
</div>

// RecentActivity.tsx - IDENTICAL CODE DUPLICATED
<div className="flex items-center gap-2">
    <span className="text-xs font-medium bg-slate-200 px-2 py-1 rounded-full">
        {activities.total}
    </span>
    <div className="flex items-center gap-1">
        <Link href={onPreviousUrl} disabled={currentPage === 1}>
            <ChevronLeft className="h-4 w-4" />
        </Link>
        <span>{currentPage}/{lastPage}</span>
        <Link href={onNextUrl} disabled={currentPage === lastPage}>
            <ChevronRight className="h-4 w-4" />
        </Link>
    </div>
</div>
```

**Good: Extract into a reusable component**
```typescript
// shared/PaginationControls.tsx
export function PaginationControls({
    currentPage,
    lastPage,
    total,
    onPreviousUrl,
    onNextUrl,
}: PaginationControlsProps) {
    return (
        <div className="flex items-center gap-2">
            <span className="text-xs font-medium bg-slate-200 px-2 py-1 rounded-full">
                {total}
            </span>
            <div className="flex items-center gap-1">
                <Link href={onPreviousUrl} disabled={currentPage === 1}>
                    <ChevronLeft className="h-4 w-4" />
                </Link>
                <span>{currentPage}/{lastPage}</span>
                <Link href={onNextUrl} disabled={currentPage === lastPage}>
                    <ChevronRight className="h-4 w-4" />
                </Link>
            </div>
        </div>
    );
}

// Campaigns.tsx - Now uses the shared component
<PaginationControls
    currentPage={campaigns.current_page}
    lastPage={campaigns.last_page}
    total={campaigns.total}
    onPreviousUrl={onPreviousUrl}
    onNextUrl={onNextUrl}
/>

// RecentActivity.tsx - Also uses the shared component
<PaginationControls
    currentPage={activities.current_page}
    lastPage={activities.last_page}
    total={activities.total}
    onPreviousUrl={onPreviousUrl}
    onNextUrl={onNextUrl}
/>
```

#### 2. **Extract Functions for Shared Logic**

When multiple components have the same logic, extract it into a utility function or custom hook.

**Bad: Duplicate pagination calculation logic**
```typescript
// Campaigns.tsx
const totalPages = Math.ceil(campaigns.length / campaignsPerPage);
const startIndex = currentPage * campaignsPerPage;
const endIndex = startIndex + campaignsPerPage;
const currentItems = campaigns.slice(startIndex, endIndex);

// RecentActivity.tsx - SAME LOGIC DUPLICATED
const totalPages = Math.ceil(activities.length / activitiesPerPage);
const startIndex = currentPage * activitiesPerPage;
const endIndex = startIndex + activitiesPerPage;
const currentItems = activities.slice(startIndex, endIndex);
```

**Good: Extract into a utility function**
```typescript
// lib/pagination.ts
export function getPaginatedItems<T>(
    items: T[],
    currentPage: number,
    itemsPerPage: number
) {
    const totalPages = Math.ceil(items.length / itemsPerPage);
    const startIndex = currentPage * itemsPerPage;
    const endIndex = startIndex + itemsPerPage;
    const paginatedItems = items.slice(startIndex, endIndex);

    return { paginatedItems, totalPages };
}

// Campaigns.tsx
const { paginatedItems, totalPages } = getPaginatedItems(
    campaigns,
    currentPage,
    campaignsPerPage
);

// RecentActivity.tsx
const { paginatedItems, totalPages } = getPaginatedItems(
    activities,
    currentPage,
    activitiesPerPage
);
```

#### 3. **Parameterize Differences**

When extracting common code, identify what varies between uses and make those differences parameters.

**Example: Generic component with parameterized differences**
```typescript
// ✅ GOOD: Differences are parameterized
export function PaginationControls({
    currentPage,
    lastPage,
    total,
    onPreviousUrl,
    onNextUrl,
}: PaginationControlsProps) {
    // Common structure, parameterized values
    return (
        <div className="flex items-center gap-2">
            <span className="text-xs font-medium bg-slate-200 px-2 py-1 rounded-full">
                {total}
            </span>
            {/* ... pagination buttons using parameters ... */}
        </div>
    );
}
```

### When NOT to Extract

Don't extract code if:
- It's only used in **one place** (no duplication yet)
- Extracting would make the code **harder to understand** (premature abstraction)
- The code is **trivial** (e.g., a single line)

However, if you're creating a new component and notice it's **very similar to an existing one**, extract the common parts **before** creating the new component. This prevents duplication from being introduced in the first place.

### Checklist Before Creating New Components

Before creating a new component, ask yourself:
- [ ] Does a similar component already exist?
- [ ] Can I reuse an existing component with different props?
- [ ] Can I extract common UI patterns into a shared component?
- [ ] Can I extract common logic into a utility function or hook?
- [ ] Are there duplicate styling patterns I should consolidate?

If you answer "yes" to any of these, refactor first before creating the new component.

## Prop Naming: Avoid Redundant Prefixes

When naming props, avoid repeating context that's already clear from the component name. The component name provides semantic meaning, so prop names should be concise.

**Bad: Redundant prefix repeats component context**
```typescript
// Component name already indicates this is about active jobs
function ActiveBadge({ activeJobsCount }: Props) { ... }
```

**Good: Prop name is concise, context comes from component name**
```typescript
function ActiveBadge({ count }: Props) { ... }
```

**Another example:**
- ❌ `<SearchBar searchQuery={query} />` — "search" is redundant
- ✅ `<SearchBar query={query} />` — context is clear from component name

This keeps code DRY and makes props more reusable across different contexts.

## Currency Formatting

### formatCurrency Utility

The `formatCurrency()` utility in `resources/js/lib/infrastructure/currency.ts` converts pence amounts to formatted currency strings with the pound symbol and thousand separators.

**Location:** `resources/js/lib/infrastructure/currency.ts`

**Function Signature:**
```typescript
export function formatCurrency(amountInCents: number): string
```

**Usage:**
```typescript
import { formatCurrency } from '@/lib/infrastructure/currency';

formatCurrency(154040)  // Returns: "£1,540.40"
formatCurrency(50)      // Returns: "£0.50"
formatCurrency(0)       // Returns: "£0.00"
```

**Key Features:**
- Converts pence (integer) to pounds with 2 decimal places
- Adds thousand separators (e.g., "£1,540.40" not "£1540.40")
- Always displays exactly 2 decimal places (e.g., "£0.50" not "£0.5")
- Adds the pound symbol (£) prefix

**When to Use:**
- Displaying monetary values from the backend (which are stored as integers in pence)
- Formatting invoice amounts, billing totals, or any financial metrics
- In wrapper components that need to format data before passing to generic display components

**Backend Storage Convention:**
All monetary values in the database are stored as **integers representing pence** to avoid floating-point precision errors. When displaying these values to users, always use `formatCurrency()` to convert them to the proper currency format.

## Branded Types for Type-Safe Currency Values

### Overview

Branded types provide compile-time type safety for currency values, preventing accidental mixing of different currencies or units. This is a TypeScript pattern that uses a private `unique symbol` to create nominal typing in a structurally-typed language.

**Location:** `resources/js/types/currency.ts`

### The Problem Branded Types Solve

Without branded types, all currency values are just plain numbers:
```typescript
// ❌ UNSAFE: No way to distinguish between different currencies
const sterlingAmount: number = 1500;  // Is this pence or pounds?
const dollarAmount: number = 5000;    // Is this cents or dollars?

// Easy to accidentally mix them
const total = sterlingAmount + dollarAmount;  // TypeScript allows this!
```

### The Solution: Branded Types

Branded types create distinct types for each currency:
```typescript
// ✅ SAFE: Each currency is a distinct type
const sterlingAmount: SterlingPence = asCurrency<SterlingPence>(1500);
const dollarAmount: DollarCents = asCurrency<DollarCents>(5000);

// TypeScript prevents mixing them
const total = sterlingAmount + dollarAmount;  // ❌ Type error!
```

### Available Branded Types

```typescript
import {
    asCurrency,
    type SterlingPence,
    type DollarCents,
    type EuroCents,
    type SupportedCurrency,
    type Metric
} from '@/types/currency';
```

**Branded Currency Types:**
- `SterlingPence` — British pounds in pence units (e.g., 1500 = £15.00)
- `DollarCents` — US dollars in cents units (e.g., 5000 = $50.00)
- `EuroCents` — Euros in cents units (e.g., 10000 = €100.00)

**Union Types:**
- `SupportedCurrency` — Union of all supported currencies (closed set)

### The Metric Discriminated Union

For dashboard metrics that can be either currency amounts or counts, use the `Metric` discriminated union from `resources/js/components/dashboard/shared/types.ts`:

```typescript
import type { Metric } from '@/components/dashboard/shared';

type Metric =
    | { kind: 'sterling'; amount: SterlingPence }
    | { kind: 'dollar'; amount: DollarCents }
    | { kind: 'euro'; amount: EuroCents }
    | { kind: 'count'; count: number };
```

This combines:
1. A **discriminator field** (`kind`) that identifies the metric type
2. **Branded types** for currency values to ensure type safety

**Location:** `resources/js/components/dashboard/shared/types.ts`

The `Metric` type is dashboard-specific (not in the currency types file) because it includes a `count` option which is not a currency value.

### Usage Pattern: Boundary Conversion

Convert backend plain numbers to branded types at the component boundary:

```typescript
import { asCurrency, type SterlingPence, type Metric } from '@/types/currency';

function MyComponent({ value }: { value: number }) {
    // Convert at the boundary
    const metric: Metric = {
        kind: 'sterling',
        amount: asCurrency<SterlingPence>(value)
    };

    // Now metric is type-safe throughout the component
    return <Summary metric={metric} />;
}
```

### Using Metrics in Components

When a component receives a `Metric`, use the discriminator to handle different types:

```typescript
function Summary({ metric }: { metric: Metric }) {
    const displayValue = metric.kind === 'count'
        ? String(metric.count)
        : formatCurrency(metric.amount);

    return <div>{displayValue}</div>;
}
```

TypeScript automatically narrows the type based on the discriminator, so:
- When `metric.kind === 'count'`, TypeScript knows `metric.count` exists
- When `metric.kind === 'sterling'`, TypeScript knows `metric.amount` is `SterlingPence`

### Extending with New Currencies

To add a new currency (e.g., YenSen):

1. **Add the branded type** in `resources/js/types/currency.ts`:
   ```typescript
   export type YenSen = number & { readonly [__brand]: 'YenSen' };
   ```

2. **Update SupportedCurrency union**:
   ```typescript
   export type SupportedCurrency = SterlingPence | DollarCents | EuroCents | YenSen;
   ```

3. **Update Metric union**:
   ```typescript
   export type Metric =
       | { kind: 'sterling'; amount: SterlingPence }
       | { kind: 'dollar'; amount: DollarCents }
       | { kind: 'euro'; amount: EuroCents }
       | { kind: 'yen'; amount: YenSen }
       | { kind: 'count'; count: number };
   ```

TypeScript will automatically report **exhaustiveness errors** in all switch statements and type guards that don't handle the new currency, forcing you to update all affected code.

### Key Benefits

- ✅ **Compile-time safety**: Prevents mixing different currencies
- ✅ **Exhaustiveness checking**: Adding new currencies forces updates everywhere
- ✅ **Zero runtime overhead**: Branded types are erased at runtime
- ✅ **Self-documenting**: Type names clearly indicate the unit (Pence, Cents)
- ✅ **Fail-fast**: Invalid data throws errors immediately, never silently converts
