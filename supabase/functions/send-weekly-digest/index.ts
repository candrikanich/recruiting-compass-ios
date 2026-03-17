import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const WEB_APP_URL = Deno.env.get('WEB_APP_URL')! // e.g. https://app.recruitingcompass.com

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  let sent = 0

  const { data: users } = await supabase
    .from('users')
    .select('id, email, timezone')

  const weekAgo = new Date()
  weekAgo.setDate(weekAgo.getDate() - 7)
  const weekAgoStr = weekAgo.toISOString()

  for (const user of users ?? []) {
    // Check preference — default to enabled
    const { data: pref } = await supabase
      .from('notification_preferences')
      .select('push_enabled, email_enabled')
      .eq('user_id', user.id)
      .eq('notification_type', 'weekly_digest')
      .maybeSingle()

    if (pref?.push_enabled === false) continue

    // Count interactions last week
    const { count: interactions } = await supabase
      .from('interactions')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('occurred_at', weekAgoStr)

    // School status changes — join through schools (no user_id on school_status_history)
    const { data: userSchools } = await supabase
      .from('schools')
      .select('id')
      .eq('user_id', user.id)

    const schoolIds = (userSchools ?? []).map((s: { id: string }) => s.id)

    const schoolChanges = schoolIds.length > 0
      ? (await supabase
          .from('school_status_history')
          .select('id', { count: 'exact', head: true })
          .in('school_id', schoolIds)
          .gte('changed_at', weekAgoStr)
        ).count ?? 0
      : 0

    // Upcoming deadlines in next 14 days
    const twoWeeks = new Date()
    twoWeeks.setDate(twoWeeks.getDate() + 14)
    const twoWeeksStr = twoWeeks.toISOString().split('T')[0]
    const todayStr = new Date().toISOString().split('T')[0]

    const { data: upcoming } = await supabase
      .from('user_deadlines')
      .select('label, deadline_date')
      .eq('user_id', user.id)
      .gte('deadline_date', todayStr)
      .lte('deadline_date', twoWeeksStr)
      .order('deadline_date')

    // Build message lines
    const hasActivity = (interactions ?? 0) > 0 || schoolChanges > 0
    const lines: string[] = hasActivity
      ? [
          `${interactions ?? 0} interaction${interactions !== 1 ? 's' : ''} logged last week`,
          ...(schoolChanges > 0 ? [`${schoolChanges} school status change${schoolChanges !== 1 ? 's' : ''}`] : []),
          ...((upcoming?.length ?? 0) > 0
            ? [`Upcoming deadlines: ${upcoming!.map(d => d.label).join(', ')}`]
            : []),
        ]
      : [
          'Quiet week — keep the momentum going!',
          'Consider reaching out to 2 coaches you haven\'t contacted recently.',
        ]

    // Insert in-app notification
    const { error: insertError } = await supabase.from('notifications').insert({
      user_id: user.id,
      type: 'weekly_digest',
      title: 'Your weekly recruiting recap',
      message: lines.join('\n'),
      priority: 'low',
      scheduled_for: new Date().toISOString(),
    })

    if (insertError) {
      console.error(`Failed to insert notification for user ${user.id}:`, insertError)
      continue
    }

    // Send email if user has an email address and email is enabled
    const emailEnabled = pref?.email_enabled !== false
    if (user.email && emailEnabled) {
      try {
        const response = await fetch(`${WEB_APP_URL}/api/email/send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            to: user.email,
            subject: 'Your weekly recruiting recap',
            template: 'weekly-digest',
            data: { lines, upcomingDeadlines: upcoming ?? [] },
          }),
        })

        if (!response.ok) {
          const errorText = await response.text()
          console.error(`Failed to send digest email for user ${user.id}: HTTP ${response.status} - ${errorText}`)
          // Don't throw — push notification already inserted, email is best-effort
        }
      } catch (err) {
        console.error(`Failed to send digest email for user ${user.id}:`, err)
        // Don't throw — push notification already inserted, email is best-effort
      }
    }

    sent++
  }

  return new Response(JSON.stringify({ sent }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})
