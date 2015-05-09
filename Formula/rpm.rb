require 'formula'

class RpmDownloadStrategy < CurlDownloadStrategy
  def stage
    tarball_name = "#{name}-#{version}.tar.gz"
    safe_system "rpm2cpio.pl <#{cached_location} | cpio -vi #{tarball_name}"
    safe_system "/usr/bin/tar -xzf #{tarball_name} && rm #{tarball_name}"
    chdir
  end

  def ext
    ".src.rpm"
  end
end

class Rpm < Formula
  homepage 'http://www.rpm5.org/'
  url 'http://rpm5.org/files/rpm/rpm-5.4/rpm-5.4.15-0.20140824.src.rpm',
      :using => RpmDownloadStrategy
  version '5.4.15'
  sha1 '5e94f4679759c36ce76a4847401b22b660a97227'

  depends_on 'berkeley-db'
  depends_on 'libmagic'
  depends_on 'popt'
  depends_on 'libtasn1'
  depends_on 'gettext'
  depends_on 'xz'
  depends_on 'ossp-uuid'
  depends_on 'rpm2cpio' => :build

  def install
    # only rpm should go into HOMEBREW_CELLAR, not rpms built
    inreplace "macros/macros.in", '@prefix@', HOMEBREW_PREFIX
    args = %W[
        --prefix=#{prefix}
        --localstatedir=#{var}
        --with-path-cfg=#{etc}/rpm
        --with-path-magic=#{HOMEBREW_PREFIX}/share/misc/magic
        --with-path-sources=#{var}/lib/rpmbuild
        --with-libiconv-prefix=/usr
        --disable-openmp
        --disable-nls
        --disable-dependency-tracking
        --with-db=external
        --with-sqlite=external
        --with-file=external
        --with-popt=external
        --with-beecrypt=internal
        --with-libtasn1=external
        --with-neon=internal
        --with-uuid=external
        --with-pcre=internal
        --with-lua=internal
        --with-syck=internal
        --without-apidocs
        varprefix=#{var}
    ]

    system "./configure", *args
    inreplace "Makefile", "--tag=CC", "--tag=CXX"
    inreplace "Makefile", "--mode=link $(CCLD)", "--mode=link $(CXX)"
    system "make"
    # enable rpmbuild macros, for building *.rpm packages
    inreplace "macros/macros", "#%%{load:%{_usrlibrpm}/macros.rpmbuild}", "%{load:%{_usrlibrpm}/macros.rpmbuild}"
    # using __scriptlet_requires needs bash --rpm-requires
    inreplace "macros/macros.rpmbuild", "%_use_internal_dependency_generator\t2", "%_use_internal_dependency_generator\t1"
    system "make install"
  end

  def test_spec
    <<-EOS.undent
      Summary:   Test package
      Name:      test
      Version:   1.0
      Release:   1
      License:   Public Domain
      Group:     Development/Tools
      BuildArch: noarch

      %description
      Trivial test package

      %prep
      %build
      %install
      mkdir -p $RPM_BUILD_ROOT/tmp
      touch $RPM_BUILD_ROOT/tmp/test

      %files
      /tmp/test

      %changelog

    EOS
  end

  def rpmdir macro
    return Pathname.new(`#{bin}/rpm --eval #{macro}`.chomp)
  end

  test do
    system "#{bin}/rpm", "-vv", "-qa"
    rpmdir('%_builddir').mkpath
    specfile = rpmdir('%_specdir')+'test.spec'
    specfile.unlink if specfile.exist?
    (specfile).write(test_spec)
    system "#{bin}/rpmbuild", "-ba", specfile
  end
end
