## 订阅与付费策略

每日免费一次echo匹配，每个echo进入的第一次chat免费，超出则需要扣除星尘（额度），每次额外echo要5星尘，每次额外chat需要1星尘。免费用户星尘为0，付费用户每月1000星尘。

技术实现：daily_free_echo_used_on，存入上次echo使用的date（当地时区），用户echo时检查daily_free_echo_used_on是否存了当日时间，如果有了则要扣出echo的额度，否则更新时期，本次免费。
每次chat时，检查前端是否传入session_id（已有了对话），还是echo_id（每个echo第一次对话），如果是echo_id并且后端查找是否有关联的session_id，如果没有说明是第一次echo的chat，本次为免费，负责扣除1额度。

### 付费用户
在免费功能的基础上，每月增加1000星尘（额度），对于revenuecat的订阅（webhook），订阅或续费后额度变为1000，expires额度变为0。免费用户额度始终为0，不用作额外多余更新。
