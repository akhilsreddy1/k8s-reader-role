# k8s-reader-role

Usage: 

```
sh create_kubeconfig.sh
```

1) Creates a k8s service account in given namespace , assigns cluster level read only permissions. 

2) Writes a token and kubeconfig file to working directory , which can be used for authenticating with cluster.
