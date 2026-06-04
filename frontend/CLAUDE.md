# Project Identity & Core Philosophy
This is the "Zhouyi" Flutter project. It is NOT a standard utility, game, or divination app. It is a structured emotional experience carrier.
When generating any code, you MUST strictly adhere to these strategic boundaries:
1. NO prediction, NO future-telling algorithms, NO "Good/Bad/Lucky" rating systems.
2. NO gamification, NO points, NO rare items, NO reward loops, NO high-frequency engagement nudges.
3. NO life advice or decision-making support algorithms. The AI acts ONLY as a restrained emotional mirror.

# Architecture & State Management
- **Tech Stack:** Flutter (Dart with Null Safety).
- **State Management:** Riverpod.
- **State Machine:** The app must follow a STRICT, one-way, irreversible 6-step linear state machine:
  1. Entry: Wait for user interaction. No auto-start.
  2. Action: Execute the physical/mocked ritual.
  3. Suspension: MANDATORY delay/waiting period with NO visual feedback.
  4. Presentation: Show hexagram result without judgment.
  5. Response: AI interaction (via Coze API).
  6. Closure: Natural end, entirely controlled by the user. No prompts to restart.

# Hardware & Service Decoupling
- The UI layer MUST be completely decoupled from the hardware/logic layer.
- Implement a `RitualService` abstract interface.
- Implement a `MockRitualServiceImpl` for current development. This must simulate 3 coins being tossed, generate a random hexagram, and enforce the `Future.delayed` for the "Suspension" stage.

# UI/UX & API Constraints
- Design must be minimalist, restrained, and culturally respectful (high-end visual).
- Animations (e.g., coin toss physics) must be highly optimized and run at 60fps+.
- Network requests to the AI Agent (Coze API) MUST support Server-Sent Events (SSE) for streaming text, ensuring a slow, typewriter-like emotional pacing.