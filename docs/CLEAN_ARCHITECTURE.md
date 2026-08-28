# Clean Architecture — Schools reference

Schools is the first feature converted from feature-MVVM to clean architecture. Behavior is unchanged. Other features still use `Models/ViewModels/Views/Components/Services` until converted the same way.

Same app target — folder layout is the module boundary, not Swift packages.

## Folder structure

```
Features/Schools/
├── Domain/                      # App rules. No SwiftUI. No Supabase.
│   ├── Entities/               # School, SchoolStatus, filters, commands
│   ├── Repositories/          # SchoolsRepository (protocol only)
│   ├── UseCases/              # Filter/sort, analytics, delete fallback
│   └── Utilities/             # Pure calculators (academic / personal fit)
├── Data/                        # How domain talks to the outside world
│   ├── Repositories/          # SchoolsRepositoryImpl (Supabase)
│   ├── DataSources/          # NCAA JSON, Scorecard API, favicon, duplicates
│   └── DTOs/                  # Wire-format API payloads
├── Presentation/               # SwiftUI edge
│   ├── ViewModels/            # UI state + orchestration
│   ├── Views/ + Components/
│   └── Models/               # Form/nav/edit state only
└── DI/
    └── SchoolsFactory.swift     # Feature composition root
```

**Compatibility aliases** (do not add new call sites):

- `SchoolsManaging` → `SchoolsRepository`
- `SchoolsServiceImpl` → `SchoolsRepositoryImpl`

## Dependency rule

```
Presentation → Domain ← Data
     │                      │
     └──── DI wires both ───┘
```

- Views construct view models through `SchoolsFactory`, not `SchoolsRepositoryImpl(...)`.
- View models depend on `SchoolsRepository` / `*Managing` protocols.
- Use cases depend on repository protocols or pure values — never SwiftUI, never `SupabaseManager`.
- Data implements Domain protocols.

## Data flow (list)

```
SchoolsListView
  → SchoolsFactory.makeListViewModel()
    → SchoolsListViewModel (UI state)
      → FilterAndSortSchoolsUseCase / ComputeSchoolAnalyticsUseCase  (pure)
      → DeleteSchoolUseCase → SchoolsRepository
        → SchoolsRepositoryImpl → Supabase
```

## What stayed the same

- Screen layout, copy, filter/sort rules, delete fallback (simple then cascade).
- Test mocks still conform to `SchoolsManaging`.
- Other features still construct `SchoolsServiceImpl` until they are converted.

## Converting the next feature

1. Relocate the feature's entity out of Dashboard if it still lives there (`Coach` is next).
2. `git mv` into `Domain/ / Data/ / Presentation/ / DI/`.
3. Promote the `*Managing` protocol to `*Repository` + typealias.
4. Extract use cases that currently live in the view model (filter/sort, multi-step mutations).
5. Add a feature factory; point views at it.
6. Leave call sites in other features on the typealias until that feature is converted.
