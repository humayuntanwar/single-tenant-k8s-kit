# Decisions

## App

1. One image for all customers. Each customer's settings come from environment variables.
   I didn't want a separate build per customer, because then you can't say every customer
   runs the same tested code.

2. Two health checks. /healthz tells Kubernetes the app is alive (if not, restart it).
   /readyz tells it the app can take traffic (if not, stop sending requests but don't kill it).

3. /crash is only there so I can practise failures. It's off unless ALLOW_CRASH is set,
   so it can't be used by accident.

4. Exact package versions in requirements.txt, so the build gives the same result every time.