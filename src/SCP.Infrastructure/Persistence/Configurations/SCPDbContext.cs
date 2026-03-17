using Microsoft.EntityFrameworkCore;
using SCP.Domain.Entities.Sys;
using SCP.Domain.Entities.Hr;

namespace SCP.Infrastructure.Persistence
{
    public class SCPDbContext : DbContext
    {
        public SCPDbContext(DbContextOptions<SCPDbContext> options) : base(options) { }

        public DbSet<SysSite> SysSites => Set<SysSite>();
        public DbSet<SysUser> SysUsers => Set<SysUser>();
        public DbSet<HrStaff> HrStaff => Set<HrStaff>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<SysSite>(b =>
            {
                b.ToTable("Sys_Sites");
                b.HasKey(x => x.SiteId);
                b.HasIndex(x => x.Name).IsUnique();
            });

            modelBuilder.Entity<SysUser>(b =>
            {
                b.ToTable("Sys_Users");
                b.HasKey(x => x.UserId);
                b.HasIndex(x => x.Username).IsUnique();
                b.HasOne(x => x.Site).WithMany(x => x.Users).HasForeignKey(x => x.SiteId);
            });

            modelBuilder.Entity<HrStaff>(b =>
            {
                b.ToTable("HR_Staff");
                b.HasKey(x => x.StaffId);
                b.HasIndex(x => x.EmployeeCode).IsUnique();
            });
        }
    }
}