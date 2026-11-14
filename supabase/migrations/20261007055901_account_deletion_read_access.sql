-- Existing access tokens must lose read access as soon as deletion is requested.
create or replace function public.is_account_active_v1()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and deletion_requested_at is null
  )
$$;
revoke all on function public.is_account_active_v1() from public, anon, authenticated;
grant execute on function public.is_account_active_v1() to authenticated, service_role;

alter policy profiles_select_own on public.profiles
  using ((select public.is_account_active_v1()) and (select auth.uid()) = id);
alter policy inbox_select_own on public.event_inbox
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy logs_select_own on public.food_logs
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy goals_select_own on public.goals
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy favorites_select_own on public.favorites
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy weights_select_own on public.weights
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy products_select_own on public.products
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy saved_meals_select_own on public.saved_meals
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy water_logs_select_own on public.water_logs
  using ((select public.is_account_active_v1()) and (select auth.uid()) = owner_id);
alter policy saved_meal_items_select_own on public.saved_meal_items
  using ((select public.is_account_active_v1()) and exists (
    select 1 from public.saved_meals meal
    where meal.id = saved_meal_id and meal.owner_id = (select auth.uid())
  ));
