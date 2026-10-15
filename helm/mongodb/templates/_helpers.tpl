{{- define "mongodb.labels" -}}
app.kubernetes.io/name: mongodb
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: godar-chat
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mongodb.selectorLabels" -}}
app.kubernetes.io/name: mongodb
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mongodb.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end -}}

{{/* host:port list of every member, in the order the replica set is initiated. */}}
{{- define "mongodb.members" -}}
{{- $ns := .Release.Namespace -}}
{{- $out := list -}}
{{- range $i := until (int .Values.replicas) -}}
{{- $out = append $out (printf "mongodb-%d.mongodb-headless.%s.svc.cluster.local:27017" $i $ns) -}}
{{- end -}}
{{- join "," $out -}}
{{- end -}}
