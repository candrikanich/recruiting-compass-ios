import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  let processed = 0

  const { data: users, error: usersError } = await supabase
    .from('users')
    .select('id, timezone')

  if (usersError) {
    console.error('Failed to fetch users:', usersError)
    return new Response(JSON.stringify({ error: 'Failed to fetch users' }), { status: 500 })
  }

  for (const user of users ?? []) {
    const tz = user.timezone ?? 'America/New_York'
    const todayInTz = new Date().toLocaleDateString('en-CA', { timeZone: tz }) // YYYY-MM-DD

    // 1. next_contact_date reminders
    const { data: coachesWithDate } = await supabase
      .from('coaches')
      .select('id, first_name, last_name, next_contact_date')
      .eq('user_id', user.id)
      .eq('next_contact_date', todayInTz)

    for (const coach of coachesWithDate ?? []) {
      const alreadySent = await checkAlertLog(supabase, user.id, coach.id)
      if (alreadySent) continue

      const name = `${coach.first_name ?? ''} ${coach.last_name ?? ''}`.trim()
      await supabase.from('notifications').insert({
        user_id: user.id,
        type: 'follow_up_reminder',
        title: `Time to contact ${name}`,
        message: `Your scheduled contact date with ${name} is today.`,
        priority: 'normal',
        related_entity_type: 'coach',
        related_entity_id: coach.id,
        related_coach_id: coach.id,
        scheduled_for: new Date().toISOString(),
      })
      await logAlert(supabase, user.id, coach.id)
      processed++
    }

    // 2. Inactivity reminders
    const { data: allCoaches } = await supabase
      .from('coaches')
      .select('id, first_name, last_name, follow_up_threshold_days')
      .eq('user_id', user.id)

    for (const coach of allCoaches ?? []) {
      const threshold = coach.follow_up_threshold_days ?? 21
      const cutoff = new Date()
      cutoff.setDate(cutoff.getDate() - threshold)
      const cutoffStr = cutoff.toLocaleDateString('en-CA', { timeZone: tz })

      const { data: recent } = await supabase
        .from('interactions')
        .select('occurred_at')
        .eq('user_id', user.id)
        .eq('coach_id', coach.id)
        .order('occurred_at', { ascending: false })
        .limit(1)

      const lastContact = recent?.[0]?.occurred_at?.split('T')[0] ?? null
      if (!lastContact || lastContact >= cutoffStr) continue

      const alreadySent = await checkAlertLog(supabase, user.id, coach.id)
      if (alreadySent) continue

      const name = `${coach.first_name ?? ''} ${coach.last_name ?? ''}`.trim()
      const daysSince = Math.round(
        (new Date().getTime() - new Date(lastContact).getTime()) / 86400000
      )

      await supabase.from('notifications').insert({
        user_id: user.id,
        type: 'follow_up_reminder',
        title: `Follow up with ${name}`,
        message: `It's been ${daysSince} days since last contact with ${name}. Reach out to stay top of mind.`,
        priority: 'normal',
        related_entity_type: 'coach',
        related_entity_id: coach.id,
        related_coach_id: coach.id,
        scheduled_for: new Date().toISOString(),
      })
      await logAlert(supabase, user.id, coach.id)
      processed++
    }
  }

  return new Response(JSON.stringify({ processed }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
})

async function checkAlertLog(supabase: ReturnType<typeof createClient>, userId: string, coachId: string): Promise<boolean> {
  const today = new Date().toISOString().split('T')[0]
  const { data } = await supabase
    .from('deadline_alert_log')
    .select('id')
    .eq('user_id', userId)
    .eq('source_table', 'coaches')
    .eq('source_id', coachId)
    .eq('alert_days_before', 0)
    .gte('sent_at', today)
    .maybeSingle()
  return !!data
}

async function logAlert(supabase: ReturnType<typeof createClient>, userId: string, coachId: string): Promise<void> {
  await supabase.from('deadline_alert_log').insert({
    user_id: userId,
    source_table: 'coaches',
    source_id: coachId,
    alert_days_before: 0,
  })
}
