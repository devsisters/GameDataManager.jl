
"""
   dice_distribution

모든면이 동일한 확률의 Dice 확률 구하기
"""
function dice_distribution(ndices::Integer, nfaces::Integer)
   function _dicetable(throw)
      v = collect(throw:nfaces*throw)
      Dict(:Outcome => v, :Weight => zero(v))
   end

   # 던지기 횟수별 확률
   dt = broadcast(i -> _dicetable(i), 1:ndices)
   base_prob = 1 / nfaces
   for i in 1:ndices
      if i == 1
         dt[i][:Weight] .= 1
      else
         prev_size = length(dt[i-1][:Outcome])

         for j in 1:length(dt[i][:Outcome])
            st = max(j-nfaces+1, 1)
            ed = min(j, length(dt[i-1][:Weight]))
            rg = st:ed

            dt[i][:Weight][j] = sum(dt[i-1][:Weight][rg])
         end
      end
   end
   return dt
end
function dice_distribution(ndices::Integer, dice::AbstractRange)
   nfaces = length(dice)

   dicetable = dice_distribution(ndices, nfaces)
   for x in dicetable
      x[:Outcome] = x[:Outcome].* step(dice)
   end
   return dicetable
end
