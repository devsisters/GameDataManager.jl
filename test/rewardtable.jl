using Test
using GameDataManager
GDM = GameDataManager


# fixed Reward
k = 1
data = get_cachedrow("RewardTable", 1, :RewardKey, k)

script = data[1]["RewardScript"]

reward = GDM.RewardScript.(script["Rewards"])

#Fixed Reward
x = RewardTable(50001)
sample(x)

#RandomReward
x = RewardTable(1001)
sample(x)


# BlockReward
x = RewardTable(1005001)
sample(x)
