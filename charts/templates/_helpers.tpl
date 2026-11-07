{{- define "redis.labels" -}}
app.kubernetes.io/name: redis
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{- define "redis.secret" -}}
{{- default (printf "%s-auth" .Release.Name) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "redis.dataHosts" -}}
{{- $hosts := list -}}
{{- $root := . -}}
{{- range $i := until (int (add 1 .Values.redis.replicas)) -}}
{{- $hosts = append $hosts (printf "%s-redis-%d.%s-redis-headless.%s.svc.%s" $root.Release.Name $i $root.Release.Name $root.Release.Namespace $root.Values.clusterDomain) -}}
{{- end -}}
{{- join " " $hosts -}}
{{- end -}}

{{- define "redis.sentinelHosts" -}}
{{- $hosts := list -}}
{{- $root := . -}}
{{- range $i := until (int .Values.sentinel.replicas) -}}
{{- $hosts = append $hosts (printf "%s-sentinel-%d.%s-sentinel-headless.%s.svc.%s" $root.Release.Name $i $root.Release.Name $root.Release.Namespace $root.Values.clusterDomain) -}}
{{- end -}}
{{- join " " $hosts -}}
{{- end -}}
