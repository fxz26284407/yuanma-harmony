#ifndef CODEX_MOBILE_P256_ENCODING_H
#define CODEX_MOBILE_P256_ENCODING_H
#include <vector>
#include <cstdint>
#include <stdexcept>
#include <cstring>
#include <algorithm>
namespace codex_encoding {
using Bytes=std::vector<uint8_t>;
inline void check(bool value){if(!value)throw std::runtime_error("Invalid P-256 encoding");}
inline Bytes spki(const Bytes& b){
 constexpr uint8_t prefix[]={0x30,0x59,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,0x42,0x00};
 if(b.size()==91){check(std::memcmp(b.data(),prefix,sizeof(prefix))==0&&b[26]==4);return b;}
 check(b.size()==65&&b[0]==4);Bytes result(prefix,prefix+sizeof(prefix));result.insert(result.end(),b.begin(),b.end());return result;
}
inline Bytes p1363(const Bytes& b){
 if(b.size()==64)return b;
 check(b.size()>=8&&b.size()<=72&&b[0]==0x30&&b[1]==b.size()-2);size_t off=2;Bytes result(64);
 for(int part=0;part<2;part++){
  check(off+2<=b.size()&&b[off++]==2);size_t n=b[off++];check(n>=1&&n<=33&&off+n<=b.size()&&(b[off]&0x80)==0);
  if(n>1&&b[off]==0){check((b[off+1]&0x80)!=0);off++;n--;}
  check(n<=32);std::copy(b.begin()+off,b.begin()+off+n,result.begin()+part*32+32-n);off+=n;
 }
 check(off==b.size());return result;
}
}
#endif
