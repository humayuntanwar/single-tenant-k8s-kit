{{- define "tenant-api.labels" -}}
app.kubernetes.io/name: tenant-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tenant-api.selectorLabels" -}}
app.kubernetes.io/name: tenant-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end}}