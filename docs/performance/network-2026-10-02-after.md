| Screen | Source | Requests | Response KB | Largest response |
|---|---|---|---|---|
| launch | app → Supabase | 37 | 260.3 | GET /rest/v1/schools (family_unit_id,select) — 88.0 KB |
| launch | app → web API | 8 | 5.8 | GET /api/schools/recommendations (athleteId,limit) — 1.6 KB |
| schools | app → Supabase | 5 | 106.4 | GET /rest/v1/schools (family_unit_id,order,select) — 88.0 KB |
| timeline | app → Supabase | 4 | 48.1 | GET /rest/v1/task (grade_level,order,select) — 44.2 KB |
| timeline | app → web API | 3 | 1.5 | GET /api/athlete/what-matters-now — 1.1 KB |
| notifications | app → Supabase | 1 | 50.6 | GET /rest/v1/notifications (order,select,user_id) — 50.6 KB |

### launch

| Request | Count | KB | Flags |
|---|---|---|---|
| `GET /rest/v1/schools (family_unit_id,select)` | 2 | 91.3 | repeated, select=*, no limit |
| `GET /rest/v1/notifications (order,select,user_id)` | 1 | 50.6 | no limit |
| `GET /rest/v1/interactions (limit,logged_by,order,select)` | 2 | 47.8 | repeated, select=* |
| `GET /rest/v1/coaches (school_id,select)` | 1 | 38.6 | select=*, no limit |
| `GET /rest/v1/school_status_history (changed_by,limit,order,select)` | 1 | 8.2 |  |
| `GET /rest/v1/events (limit,order,select,user_id)` | 1 | 7.1 | select=* |
| `GET /rest/v1/performance_metrics (limit,order,select,user_id)` | 1 | 3.8 | select=* |
| `GET /rest/v1/users (id,select)` | 3 | 3.8 | repeated, no limit |
| `GET /rest/v1/schools (id,select)` | 1 | 2.5 | no limit |
| `GET /api/athlete/what-matters-now` | 2 | 2.2 | repeated |
| `POST /auth/v1/token (grant_type)` | 1 | 1.9 |  |
| `GET /rest/v1/user_deadlines (family_unit_id,order,select)` | 1 | 1.7 | select=*, no limit |
| `GET /api/schools/recommendations (athleteId,limit)` | 1 | 1.6 |  |
| `GET /api/suggestions (location)` | 1 | 1.3 |  |
| `GET /rest/v1/user_preferences (category,select,user_id)` | 4 | 0.9 | repeated, no limit |
| `GET /rest/v1/users (id,limit,select)` | 3 | 0.8 | repeated |
| `GET /api/athlete/phase` | 2 | 0.4 | repeated |
| `GET /rest/v1/family_members (family_unit_id,order,select)` | 1 | 0.4 | no limit |
| `GET /api/athlete/status` | 2 | 0.4 | repeated |
| `GET /rest/v1/family_units (id,limit,select)` | 1 | 0.3 | select=* |
| `GET /rest/v1/family_members (limit,select,user_id)` | 2 | 0.3 | repeated |
| `GET /rest/v1/offers (select,user_id)` | 1 | 0.1 | no limit |
| `POST /rest/v1/rpc/get_ios_version_policy` | 1 | 0.1 |  |
| `POST /rest/v1/notification_preferences (columns,on_conflict)` | 1 | 0.0 |  |
| `GET /rest/v1/documents (limit,order,select,user_id)` | 1 | 0.0 |  |
| `GET /rest/v1/video_links (order,select,user_id)` | 1 | 0.0 | select=*, no limit |
| `HEAD /rest/v1/notifications (read_at,select,user_id)` | 1 | 0.0 |  |
| `HEAD /rest/v1/interactions (logged_by,select)` | 1 | 0.0 |  |
| `HEAD /rest/v1/interactions (created_at,created_at,logged_by,occurred_at,select)` | 1 | 0.0 |  |
| `HEAD /rest/v1/interactions (logged_by,occurred_at,occurred_at,select)` | 1 | 0.0 |  |
| `HEAD /rest/v1/coaches (school_id,select)` | 1 | 0.0 |  |
| `HEAD /rest/v1/events (select,start_date,user_id)` | 1 | 0.0 |  |

### schools

| Request | Count | KB | Flags |
|---|---|---|---|
| `GET /rest/v1/schools (family_unit_id,order,select)` | 1 | 88.0 | select=*, no limit |
| `GET /rest/v1/interactions (family_unit_id,select)` | 1 | 17.7 | no limit |
| `GET /rest/v1/user_preferences (category,select,user_id)` | 2 | 0.5 | repeated, no limit |
| `GET /rest/v1/events (select,type,user_id)` | 1 | 0.1 | no limit |

### timeline

| Request | Count | KB | Flags |
|---|---|---|---|
| `GET /rest/v1/task (grade_level,order,select)` | 1 | 44.2 | select=*, no limit |
| `GET /rest/v1/athlete_task (athlete_id,select)` | 1 | 3.6 | select=*, no limit |
| `GET /api/athlete/what-matters-now` | 1 | 1.1 |  |
| `GET /rest/v1/user_preferences (category,select,user_id)` | 1 | 0.4 | no limit |
| `GET /api/athlete/phase` | 1 | 0.2 |  |
| `GET /api/athlete/status` | 1 | 0.2 |  |
| `GET /rest/v1/users (id,limit,select)` | 1 | 0.0 |  |

### notifications

| Request | Count | KB | Flags |
|---|---|---|---|
| `GET /rest/v1/notifications (order,select,user_id)` | 1 | 50.6 | no limit |
