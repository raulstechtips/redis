{{- define "redis.name" -}}
{{- .Chart.Name | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{- define "redis.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 40 | trimSuffix "-" -}}
{{- else if eq .Release.Name .Chart.Name -}}
{{- .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 40 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "redis.labels" -}}
app.kubernetes.io/name: {{ include "redis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{- define "redis.secret" -}}
{{- if .Values.auth.infisical.enabled -}}
{{- printf "%s-credentials" (include "redis.fullname" .) -}}
{{- else -}}
{{- default (printf "%s-credentials" (include "redis.fullname" .)) .Values.auth.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "redis.image" -}}
{{- if and .Values.image.useBuiltImage .Values.image.built.tag -}}
{{- printf "%s:%s" .Values.image.built.repository .Values.image.built.tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "redis.tlsSecret" -}}
{{- default (printf "%s-tls" (include "redis.fullname" .)) .Values.tls.existingSecret -}}
{{- end -}}

{{- define "redis.dataHosts" -}}
{{- $hosts := list -}}
{{- $root := . -}}
{{- range $i := until (int (add 1 .Values.redis.replicas)) -}}
{{- $hosts = append $hosts (printf "%s-node-%d.%s-node-headless.%s.svc.%s" (include "redis.fullname" $root) $i (include "redis.fullname" $root) $root.Release.Namespace $root.Values.clusterDomain) -}}
{{- end -}}
{{- join " " $hosts -}}
{{- end -}}

{{- define "redis.sentinelHosts" -}}
{{- $hosts := list -}}
{{- $root := . -}}
{{- range $i := until (int .Values.sentinel.replicas) -}}
{{- $hosts = append $hosts (printf "%s-sentinel-%d.%s-sentinel-headless.%s.svc.%s" (include "redis.fullname" $root) $i (include "redis.fullname" $root) $root.Release.Namespace $root.Values.clusterDomain) -}}
{{- end -}}
{{- join " " $hosts -}}
{{- end -}}
