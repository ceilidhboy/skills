---
name: component-composition-patterns
description: Building reusable components through composition using generic base components with specific wrapper components that provide styling, configuration, and domain-specific behavior.
author: Mike Scott
---

# Component Composition Patterns

## When to Activate This Skill

Activate this skill whenever you are:
- Creating reusable components that will be used in multiple contexts with different styling
- Building a generic base component and specific wrapper components around it
- Implementing configuration-driven component behavior
- Separating presentation logic from styling/theming logic
- Creating components that follow the composition pattern (generic + wrappers)

## The Composition Pattern

This pattern separates concerns into three layers:

1. **Generic Base Component** — Pure presentation, no styling decisions
2. **Wrapper Components** — Domain-specific styling and configuration
3. **Configuration Files** — Type definitions and styling mappings

### Example: Statistics Widget Pattern

**Layer 1: Generic Base Component** (`shared/Statistics.tsx`)
```typescript
// Pure presentation - accepts all styling as props
export function Statistics({ 
  label, 
  icon: Icon, 
  value, 
  amountInCents, 
  colorPalette 
}: StatisticsProps) {
  return (
    <div className={cn('relative flex flex-col gap-4 px-4 py-4 rounded-lg border', 
      colorPalette.bgColor, 
      colorPalette.borderColor)}>
      {/* Icon */}
      <div className="absolute top-3 right-3">
        <div className={cn('flex items-center justify-center size-10 rounded-md', 
          colorPalette.iconBgColor)}>
          <Icon className={cn('size-6', colorPalette.textColor)} />
        </div>
      </div>
      {/* Label and Value */}
      <span className="text-sm text-slate-500 pr-12">{label}</span>
      <div className="flex items-baseline justify-between">
        <span className="text-xl font-bold">{value}</span>
        {amountInCents && <span className={cn('text-sm font-medium', colorPalette.textColor)}>
          {formatCurrency(amountInCents)}
        </span>}
      </div>
    </div>
  );
}
```

**Layer 2: Wrapper Component** (`action-required/ActionStatistics.tsx`)
```typescript
// Domain-specific wrapper - handles ActionRequired styling
export function ActionStatistics({ type, value, amountInCents }: ActionStatisticsProps) {
  const config = generateWidgetConfig(type);
  
  return (
    <Statistics 
      label={config.label}
      icon={config.icon}
      value={value}
      amountInCents={amountInCents}
      colorPalette={config.colorPalette}
    />
  );
}
```

**Layer 3: Configuration** (`action-required/config.ts`)
```typescript
// Type definitions and styling mappings
export type ActionWidgetType = 'jobsNeedingWorkers' | 'overdueInvoices' | ...;

const widgetTypeToColorPalette: Record<ActionWidgetType, ColorPalette> = {
  jobsNeedingWorkers: 'amber',
  overdueInvoices: 'red',
  // ...
};

export function generateWidgetConfig(type: ActionWidgetType): Config {
  const palette = widgetTypeToColorPalette[type];
  return {
    label: labelMap[type],
    icon: iconMap[type],
    colorPalette: colorSchemes[palette],
  };
}
```

## Benefits

- **DRY**: Widget layout logic lives in one place
- **Flexible**: Each domain (ActionRequired, KeyPerformance) has its own styling
- **Maintainable**: Changes to widget structure only need to be made once
- **Type Safe**: Each domain has its own type definitions
- **Scalable**: Easy to add new domains without modifying the base component

## File Structure

```
resources/js/components/dashboard/
├── shared/
│   ├── Statistics.tsx          # Generic base component
│   └── index.ts
├── action-required/
│   ├── ActionStatistics.tsx    # Wrapper for ActionRequired
│   ├── config.ts               # ActionRequired config
│   └── index.ts
└── key-performance/
    ├── KeyPerformanceStatistics.tsx  # Wrapper for KeyPerformance
    ├── config.ts                     # KeyPerformance config
    └── index.ts
```

## Key Principles

1. **Separation of Concerns**: Base component handles layout, wrappers handle styling
2. **Configuration-Driven**: All styling decisions live in config files
3. **Type Safety**: Each domain has its own type definitions
4. **Parallel Structure**: Mirror the structure across different domains for consistency
5. **Minimal Props**: Base component accepts only what it needs to render

