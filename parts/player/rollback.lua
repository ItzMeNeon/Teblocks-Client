-- rollback.lua — ring buffer of Player snapshots for client rollback.
-- (plan_rollback.md Component 3, §3.1.)
--
-- Usage from net_game.lua (a later slice):
--
--   Rollback.save(P)                   -- at every confirmed frame
--   Rollback.restoreTo(P, frameRun)    -- on 1412 rollback trigger / 1410 snapshot mismatch
--   local f = Rollback.findBefore(P, frameRun)  -- nearest prior confirmed frame
--
-- The buffer is keyed by frameRun so a 1412 trigger at frame F can find the
-- nearest prior confirmed frame without scanning the whole ring. N defaults
-- to 12 = 200ms @ 60Hz, the minimum needed to absorb a typical RTT spike; the
-- server's snapshot interval (20Hz) and TCP/WebSocket buffering extend the
-- effective recovery window beyond this in practice.

local snapshot=require'parts.player.snapshot'
local ins=table.insert

-- snapshot interval and ring size for rollback netcode (plan §3.1).
-- The server broadcasts authoritative 1410 snapshots at 20Hz (every 3
-- frames at 60Hz) — see Match.runSimLoop in the server. We match that
-- rate on the client: a snapshot every 3 frames gives 3 × 8 = 24
-- frames (400ms) of rollback window, which is more than enough for a
-- typical RTT spike. At the original 60Hz × 12 ring, every game
-- frame did a full Player deep copy (field, stat arrays, queues, RNG
-- state) for each player — 120 deep copies/sec, which is the root
-- cause of the ranked-match performance drop. The 5x reduction here
-- brings the per-frame overhead back in line with the pre-rollback
-- baseline while keeping enough history for a typical rollback.
local SNAPSHOT_INTERVAL = 3
local RING_CAPACITY = 8

local M={
    capacity=RING_CAPACITY,
    history={},
    _index={},
    _oldest=1,
    _size=0,
    -- the highest frameRun the server has acknowledged (rollback anchor)
    ackFrame=0,
    -- frameRun at which the next snapshot should be taken
    nextSnapshotFrame=0,
}

function M.reset()
    M.history={}
    M._index={}
    M._oldest=1
    M._size=0
    M.ackFrame=0
    M.nextSnapshotFrame=0
end

function M.setCapacity(n)
    n=math.floor(n)
    if n<2 then n=2 end
    if n==M.capacity then return end
    -- Drain in order so we can rewrite into a fresh ring of size n. Oldest-
    -- first walk preserves insertion order.
    local ordered={}
    for _,entry in next,M.history do
        ins(ordered, entry)
    end
    table.sort(ordered, function(a,b) return a.frameRun<b.frameRun end)
    -- If n is smaller, drop the oldest.
    while #ordered>n do
        local dropped=table.remove(ordered, 1)
        M._index[dropped.frameRun]=nil
    end
    M.capacity=n
    M.history={}
    M._index={}
    M._oldest=1
    M._size=0
    for _,entry in next,ordered do
        M.history[M._oldest]=entry
        M._index[entry.frameRun]=M._oldest
        M._oldest=M._oldest%n+1
        M._size=M._size+1
    end
end

-- M.save(P) — capture P:snapshotState() at the current frameRun. Drop-oldest
-- when the buffer is full. Same-frame snapshots overwrite in place.
function M.save(P)
    local f=P.frameRun
    if M._index[f] then
        M.history[M._index[f]].snap=snapshot.snapshot(P)
        return
    end
    if M._size==M.capacity then
        local dropped=M.history[M._oldest]
        if dropped then M._index[dropped.frameRun]=nil end
    else
        M._size=M._size+1
    end
    M.history[M._oldest]={snap=snapshot.snapshot(P),frameRun=f}
    M._index[f]=M._oldest
    M._oldest=M._oldest%M.capacity+1
end

-- M.hasFrame(frameRun) — is a snapshot for this exact frame in the buffer?
function M.hasFrame(frameRun)
    return M._index[frameRun]~=nil
end

-- M.findBefore(frameRun) — highest saved frameRun strictly less than `frameRun`,
-- or nil if none. Used to locate the rollback anchor when a 1412 trigger or
-- 1410 snapshot asks us to roll back to frame F.
function M.findBefore(frameRun)
    local best,bestFrame=nil,-1
    for f,_ in next,M._index do
        if f<frameRun and f>bestFrame then
            bestFrame=f
            best=f
        end
    end
    return best
end

-- M.restoreTo(P, frameRun) — find the saved snapshot at or before frameRun
-- and apply it to P. Returns the frameRun actually restored, or nil if none.
function M.restoreTo(P, frameRun)
    local target=M._index[frameRun] and frameRun or M.findBefore(frameRun)
    if not target then return nil end
    local slot=M._index[target]
    local entry=M.history[slot]
    if not entry then return nil end
    snapshot.restore(P, entry.snap)
    return target
end

-- M.recordAck(frameRun) — update the rollback anchor from a 1411 inputAck.
-- The anchor is the highest frame the server has confirmed; resims must stop
-- here.
function M.recordAck(frameRun)
    if frameRun>M.ackFrame then M.ackFrame=frameRun end
end

-- M.step(players, dt) — per-scene-tick entry point.
--
-- Phase 1 (predict): local inputs have already been applied in Player:pressKey
-- / Player:releaseKey (the existing input path). No work to do here — the
-- client has zero perceived input lag by construction.
--
-- Phase 2 (advance): step each player's Player:update(dt) in lockstep. This
-- advances every player's frameRun by 1 (or more, depending on dt). The
-- fixed-step internals of update_alive handle the per-frame sim; we just
-- have to make sure both players' update() calls happen in the same tick.
--
-- Phase 3 (snapshot): save each player's state at the post-step frameRun, so
-- future rolls can restore.
--
-- Phase 4 (reconcile, gated): if NET._rollbackEnabled and NET._pendingSnapshot
-- is set, delegate to M._reconcile. Default off — visible behavior is
-- identical to the legacy path until the rollback layer is enabled by the
-- integration test harness in slice 4.
local function _inRankedRoom()
    -- The rollback history is only useful when the server is sending
    -- 1410 authoritative snapshots (ranked rooms only). Casual rooms
    -- never set NET._pendingSnapshot, so saving snapshots there is
    -- pure waste — and the deep copies are enough to cause visible
    -- stutter with 2+ bots on the host (3 players × 20Hz × 10+ table
    -- copies per snapshot = 600 deep copies/sec). Returning false in
    -- casual skips Phase 3 entirely.
    if NET and NET.roomState and NET.roomState.info then
        return NET.roomState.info.type == 'ranked'
    end
    return false
end

function M.step(players, dt)
    if not players or #players==0 then return end
    local ranked = _inRankedRoom()
    -- Phase 2: advance players in lockstep. In ranked rooms the remote
    -- (opponent) player is snapshot-driven — it is written by the server's
    -- 1410 snapshots via applyServerState, NOT locally simulated. Skipping
    -- its Player:update here prevents it from running the local all-gravity
    -- sim (which would diverge from the server) and from the bursty stream
    -- catch-up throttle that caused the timer stutter. Casual rooms keep the
    -- legacy lockstep for all players.
    for i=1,#players do
        local P=players[i]
        if P and P.update then
            P:update(dt)
        end
    end
    -- Phase 3: snapshot at the server's snapshot rate (every
    -- SNAPSHOT_INTERVAL frames). We only need enough history to cover
    -- the worst-case ack latency (SNAPSHOT_INTERVAL × RING_CAPACITY =
    -- 24 frames = 400ms). Taking a full Player deep copy every frame
    -- is the root cause of the ranked-match performance drop — at
    -- 60Hz × 2 players it was 120 deep copies/sec of large tables
    -- (field, stat arrays, queues, RNG state). The server's 20Hz
    -- snapshot rate is the natural cadence for client-side rollback
    -- history: rollbacks beyond one snapshot interval require a full
    -- server resync anyway, and the 1412 path covers divergence within
    -- the window.
    --
    -- Skipped in casual rooms: snapshots are never consumed there
    -- (no 1410/1412 traffic), so the deep copies are pure overhead.
    -- Also skipped for remote players in ranked (they are snapshot-driven
    -- and have no local history to roll back).
    if ranked and players[1] and players[1].frameRun >= M.nextSnapshotFrame then
        for i=1,#players do
            local P=players[i]
            if P and P.type~='remote' then M.save(P) end
        end
        M.nextSnapshotFrame = players[1].frameRun + SNAPSHOT_INTERVAL
    end
    -- Phase 4: reconcile if a server snapshot arrived. Also gated on
    -- ranked: 1410/1412 never fire in casual, so this branch is dead
    -- there and we save the function-call overhead of the check.
    if NET and NET._rollbackEnabled and NET._pendingSnapshot then
        local snap=NET._pendingSnapshot
        NET._pendingSnapshot=false
        M._reconcile(players, snap)
    end
end

-- M._reconcile(players, snap) — apply a server 1410 authoritative snapshot.
--
-- The snapshot is the single source of truth for the *opponent* (remote
-- player): its board is written verbatim from the server's full-state entry
-- via snapshot.applyServerState. This replaces the legacy player_stream
-- replay + catch-up throttle that previously advanced the opponent's board
-- in bursty 1/2/3/5/…-frame steps (the visible timer stutter).
--
-- The *local* player keeps predicting locally (zero perceived input lag) and
-- is only reconciled when the server reports divergence (1412) — it is NOT
-- overwritten by the snapshot, since its local prediction is already ahead of
-- the server's acked state and overwriting it would rewind the board.
--
-- The snapshot shape: { frameRun, players=[{uid,sid,frameRun,field,cur,
-- nextQueue,holdQueue,atkBuffer,stat,…}, …] } (see SimPlayer.StateJSON).
function M._reconcile(players, snap)
    if not players or not snap or not snap.players then return end

    -- Map snapshot entries to live players by uid (fallback: sid).
    local byUid, bySid = {}, {}
    for i=1,#players do
        local P=players[i]
        if P and P.uid then byUid[P.uid]=P end
        if P and P.sid then bySid[P.sid]=P end
    end

    for i=1,#snap.players do
        local se = snap.players[i]
        if not se then break end
        local P = byUid[se.uid] or bySid[se.sid]
        if not P then break end

        if P.type=='remote' then
            -- Opponent: drive directly from the authoritative snapshot.
            snapshot.applyServerState(P, se)
        else
            -- Local player: prediction is authoritative for display; do not
            -- overwrite. (Divergence correction stays on the 1412 path.)
        end
    end
end

return M