---
description: "Generate a complete production-ready Kubernetes deploy/ folder — Deployment, Service, Ingress, HorizontalPodAutoscaler, and PodDisruptionBudget. Use when deploying a Go service to Kubernetes and need production-grade scaling, traffic management, and availability guarantees."
name: "Kubernetes Deploy"
argument-hint: "Service name and any specifics (e.g. 'ai-engineer, needs TLS ingress, min 2 replicas')"
agent: "agent"
tools: ["codebase"]
---

Generate a complete `deploy/` folder for the service described in the argument. Search the codebase for: the service name, exposed port (check `main.go`), and existing `deploy/` files before generating.

## Files to Create or Update

| File | Purpose |
|------|---------|
| `deploy/deployment.yaml` | Workload — replicas, probes, security context, resources |
| `deploy/service.yaml` | ClusterIP — internal routing |
| `deploy/ingress.yaml` | External traffic — TLS, host routing |
| `deploy/hpa.yaml` | HorizontalPodAutoscaler — CPU/memory-based scaling |
| `deploy/pdb.yaml` | PodDisruptionBudget — availability during node drain |

---

## deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <name>
  namespace: default
  labels:
    app: <name>
spec:
  replicas: 2
  selector:
    matchLabels:
      app: <name>
  template:
    metadata:
      labels:
        app: <name>
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: <name>
          image: <registry>/<name>:<tag>
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: ADDR
              value: ":8080"
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 3
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
      terminationGracePeriodSeconds: 30
```

## service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <name>
  namespace: default
  labels:
    app: <name>
spec:
  type: ClusterIP
  selector:
    app: <name>
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
```

## ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <name>
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - <name>.example.com   # replace with actual hostname
      secretName: <name>-tls
  rules:
    - host: <name>.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <name>
                port:
                  name: http
```

## hpa.yaml

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <name>
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <name>
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

## pdb.yaml

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <name>
  namespace: default
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: <name>
```

## Rules

- Replace every `<name>` with the actual service name (lowercase, hyphens)
- Replace `<registry>/<name>:<tag>` with the real image — never use `latest` in production
- Replace `<name>.example.com` with the actual hostname; if TLS is not needed, remove the `tls:` block
- `minAvailable` in PDB must always be less than `replicas` in Deployment (default: 1 < 2)
- HPA `minReplicas` must equal Deployment `replicas` to avoid conflict
- After generating, run: `kubectl apply --dry-run=server -f deploy/` to validate

## Checklist

- [ ] All `<name>` placeholders substituted
- [ ] Image tag is a pinned version, not `latest`
- [ ] Hostname updated in Ingress
- [ ] `pdb.yaml` `minAvailable` < Deployment `replicas`
- [ ] `hpa.yaml` `minReplicas` matches Deployment `replicas`
- [ ] `kubectl apply --dry-run=server -f deploy/` passes
