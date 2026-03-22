  结构化优化方案（建议分三步）

  1. 第一阶段（低风险，先减写放大）

  - refresh_user_billing_state 改为“仅字段变化才 UPDATE”。
  - 去掉 SQL 里手动 updated_at = NOW()，统一由 moddatetime 触发器维护。
  - chat 扣积分后移到关键校验后。
  - resonance 改成单条 UPSERT（ON CONFLICT (user_id, souler_id)）。

  2. 第二阶段（中风险，减调用次数）

  - 增加 consume_user_credit_batch(p_user_id, p_count)，echo 一次预扣，不再 1+N 调用。
  - webhook 去掉 userExists 预查，直接走同步函数并做可控异常处理。
  - 客户端 refreshBillingState 加 TTL/防抖（例如 30-60s 内只允许一次主动刷新）。

  3. 第三阶段（架构收敛）

  - 增加 get_my_credit_state()（基于 auth.uid()），客户端可直连 RPC，评估下线 billing-sync edge function。
  - 把 next_reset_at 计算抽成一个 SQL helper，消除重复 CASE 逻辑。
