begin;
select plan(4);
select ok(matlogg_internal.valid_portion_nutrients('{"salt":0.8,"saturatedFat":0,"iron":2,"calcium":120,"iodine":15}'), 'new nutrients and zero are accepted');
select ok(not matlogg_internal.valid_portion_nutrients('{"iodine":-1}'), 'negative iodine rejected');
select ok(not matlogg_internal.valid_portion_nutrients('{"calcium":"120"}'), 'string quantity rejected');
select ok(not matlogg_internal.valid_portion_nutrients('{"unknown":1}'), 'unknown nutrient rejected');
select * from finish();
rollback;
