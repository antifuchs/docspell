CREATE TABLE `classifier_model`(
  `id` varchar(254) not null primary key,
  `cid` varchar(254) not null,
  `name` varchar(254) not null,
  `file_id` varchar(254) not null,
  `created` timestamp not null,
  foreign key (`cid`) references `collective`(`cid`),
  foreign key (`file_id`) references `filemeta`(`id`),
  unique (`cid`, `name`)
);

insert into `classifier_model`
select md5(rand()) as id, `cid`,concat('tagcategory-', `category`) as `name`, `file_id`, `created`
from `classifier_setting`
where `file_id` is not null;

alter table `classifier_setting`
add column (`categories` mediumtext);

alter table `classifier_setting`
add column (`category_list_type` varchar(254));

update `classifier_setting`
set `category_list_type` = 'whitelist';

update `classifier_setting`
set `categories` = concat('["', `category`, '"]')
where category is not null;

update `classifier_setting`
set `categories` = '[]'
where category is null;

alter table `classifier_setting`
drop column `category`;

-- mariadb requires to drop constraint manually when dropping a column
alter table `classifier_setting`
drop constraint `classifier_setting_ibfk_2`;

alter table `classifier_setting`
drop column `file_id`;

ALTER TABLE `classifier_setting`
MODIFY `categories` mediumtext NOT NULL;

ALTER TABLE `classifier_setting`
MODIFY `category_list_type` varchar(254) NOT NULL;
