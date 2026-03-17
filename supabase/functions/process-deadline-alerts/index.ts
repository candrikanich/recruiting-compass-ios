import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ALERT_DAYS = [7, 3, 0]

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: users, error: usersError } = await supabase
    .from('users')
    .select('id, timezone')

  if (usersError) {
    console.error('Failed to fetch users:', usersError)
    return new Response(JSON.stringify({ error: 'Failed to fetch users' }), { status: 500 })
  }
  let processed = 0

  for (const user of users ?? []) {
    const tz = user.timezone ?? 'America/New_York'
    const todayStr = new Date().toLocaleDateString('en-CA', { timeZone: tz })
    const today = new Date(todayStr)

    // Collect deadlines from all 4 sources
    const deadlines: Array<{
      source_table: string
      source_id: string
      deadline_date: string
      label: string
      priority: 'high' | 'normal'
    }> = []

    // Source 1: user_deadlines
    const { data: ud } = await supabase
      .from('user_deadlines')
      .select('id, label, deadline_date')
      .eq('user_id', user.id)
      .gte('deadline_date', todayStr)

    for (const d of ud ?? []) {
      deadlines.push({ source_table: 'user_deadlines', source_id: d.id, deadline_date: d.deadline_date, label: d.label, priority: 'normal' })
    }

    // Source 2: offers with deadline_date
    const { data: offers } = await supabase
      .from('offers')
      .select('id, deadline_date, schools(name)')
      .eq('user_id', user.id)
      .not('deadline_date', 'is', null)
      .in('status', ['verbal', 'official', 'pending'])

    for (const o of offers ?? []) {
      const schoolName = (o.schools as { name: string } | null)?.name ?? 'Unknown School'
      deadlines.push({
        source_table: 'offers',
        source_id: o.id,
        deadline_date: o.deadline_date,
        label: `Offer deadline: ${schoolName}`,
        priority: 'high',
      })
    }

    // Source 3: system_calendar
    const { data: userDetail } = await supabase
      .from('users')
      .select('player_details')
      .eq('id', user.id)
      .single()

    const gradYear = (userDetail?.player_details as { graduation_year?: number } | null)?.graduation_year
    const sport = (userDetail?.player_details as { primary_sport?: string } | null)?.primary_sport

    if (gradYear) {
      const { data: sc } = await supabase
        .from('system_calendar')
        .select('id, label, start_date')
        .eq('season_year', gradYear)
        .gte('start_date', todayStr)
        .or(sport ? `sport.is.null,sport.eq.${sport}` : 'sport.is.null')

      for (const s of sc ?? []) {
        deadlines.push({ source_table: 'system_calendar', source_id: s.id, deadline_date: s.start_date, label: s.label, priority: 'normal' })
      }
    }

    // Source 4: upcoming visits
    const { data: visits } = await supabase
      .from('events')
      .select('id, name, start_date')
      .eq('user_id', user.id)
      .in('type', ['official_visit', 'unofficial_visit'])
      .gte('start_date', todayStr)

    for (const v of visits ?? []) {
      deadlines.push({ source_table: 'events', source_id: v.id, deadline_date: v.start_date, label: `Visit: ${v.name}`, priority: 'normal' })
    }

    // Fire alerts
    for (const d of deadlines) {
      const deadlineDate = new Date(d.deadline_date)
      const daysUntil = Math.round((deadlineDate.getTime() - today.getTime()) / 86400000)

      for (const alertDays of ALERT_DAYS) {
        if (daysUntil !== alertDays) continue

        // Check dedup
        const { data: existing } = await supabase
          .from('deadline_alert_log')
          .select('id')
          .eq('user_id', user.id)
          .eq('source_table', d.source_table)
          .eq('source_id', d.source_id)
          .eq('alert_days_before', alertDays)
          .maybeSingle()

        if (existing) continue

        const title = alertDays === 0 ? `Today: ${d.label}` : `${alertDays} days: ${d.label}`
        const message = alertDays === 0
          ? `${d.label} is today.`
          : `${d.label} is in ${alertDays} day${alertDays !== 1 ? 's' : ''}.`

        await supabase.from('notifications').insert({
          user_id: user.id,
          type: 'deadline_alert',
          title,
          message,
          priority: alertDays <= 3 ? 'high' : d.priority,
          scheduled_for: new Date().toISOString(),
        })

        await supabase.from('deadline_alert_log').insert({
          user_id: user.id,
          source_table: d.source_table,
          source_id: d.source_id,
          alert_days_before: alertDays,
        })

        processed++
      }
    }
  }

  return new Response(JSON.stringify({ processed }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
