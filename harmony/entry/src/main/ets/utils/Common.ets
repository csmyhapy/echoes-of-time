import { router } from '@kit.ArkUI';

/**
 * 页面跳转参数与通用小工具。
 * 统一走 @ohos.router，参数是普通对象；页面用 router.getParams() 取出再做强转。
 */

export interface PersonParams {
  personId: string;
}

export interface NodeParams {
  personId: string;
  nodeId: string;
}

export interface PhotoParams {
  personId: string;
  nodeId: string;
  photoId: string;
}

export function goPerson(personId: string): void {
  router.pushUrl({ url: 'pages/person/PersonPage', params: { personId: personId } as PersonParams });
}

export function goNode(personId: string, nodeId: string): void {
  router.pushUrl({ url: 'pages/node/NodePage', params: { personId: personId, nodeId: nodeId } as NodeParams });
}

export function goPhoto(personId: string, nodeId: string, photoId: string): void {
  router.pushUrl({
    url: 'pages/photo/PhotoPage',
    params: { personId: personId, nodeId: nodeId, photoId: photoId } as PhotoParams
  });
}

/** Reader 模式：字号放大倍数（Editor 恒为 1） */
export function readerScale(mode: string, largeText: boolean): number {
  if (mode !== 'reader') {
    return 1;
  }
  return largeText ? 1.45 : 1.15;
}

export function fmtDuration(seconds: number): string {
  const total: number = Math.max(0, Math.round(seconds));
  const m: number = Math.floor(total / 60);
  const s: number = total % 60;
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

export function fmtDate(timestamp: number): string {
  const d: Date = new Date(timestamp);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function pad(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}
