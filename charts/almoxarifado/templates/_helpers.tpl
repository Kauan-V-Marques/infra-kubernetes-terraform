{{- define "almox.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "almox.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Uso: include "almox.selector" (dict "ctx" $ "component" "api") */}}
{{- define "almox.selector" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/* Imagem com tag obrigatória: nada de "latest" implícito */}}
{{- define "almox.image" -}}
{{- $tag := required (printf "%s.image.tag é obrigatório" .name) .image.tag -}}
{{- printf "%s:%s" .image.repository $tag -}}
{{- end -}}

{{- define "almox.secretName" -}}
{{- required "existingSecret é obrigatório (Secret com POSTGRES_PASSWORD, DATABASE_URL e JWT_SECRET)" .Values.existingSecret -}}
{{- end -}}

{{/* Pod sem privilégios (compatível com o Pod Security Standard "restricted") */}}
{{- define "almox.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: {{ . }}
runAsGroup: {{ . }}
fsGroup: {{ . }}
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "almox.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end -}}
