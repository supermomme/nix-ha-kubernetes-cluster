{ lib, ... }:
let

in
rec {
  clusterNodes = [
    {
      hostname = "utm-nixos1";
      ip = "10.211.55.9";
      etcd = true;

      controlPlane = true;
      # apiserver = true; # part of controlPlane
      # controllerManager = true; # part of controlPlane
      # scheduler = true; # part of controlPlane

    }
    {
      hostname = "utm-nixos2";
      ip = "10.211.55.10";
      etcd = true;

      controlPlane = true;
      # apiserver = true; # part of controlPlane
      # controllerManager = true; # part of controlPlane
      # scheduler = true; # part of controlPlane

      workerNode = true;
    }
    {
      hostname = "utm-nixos3";
      ip = "10.211.55.11";
      etcd = true;

      workerNode = true;
    }
  ];
}