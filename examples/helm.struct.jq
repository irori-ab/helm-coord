{
    "helm" : {
        "NAME" : "myRelease",
        "CHART" : "my-chart",
        "version" : "1.2.3",
        "namespace" : ["hc-testing-", .params.ENV],
        "//can-comment-out-keys" : "this-key-val-pair-will-not-be-used",
        "//kubeconfig" : ["~/.kube/config_", .params.ENV],
        "create-namespace" : "true",
        "install" : true
    },
    "valuesPaths" : [
        "environments/values.yaml",
        ["profiles/", .params.PROFILE, "/values.yaml"],
        ["environments/", .params.ENV, "/values.yaml"]
    ]
}